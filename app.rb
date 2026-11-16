# frozen_string_literal: true

require 'active_support'
require 'active_support/cache'
require 'connection_pool'
require 'rack/attack'
require 'rack/cors'
require 'redis'
require 'sinatra'
require 'sinatra/activerecord'
require 'uri'
require_relative 'models/link'

use Rack::Cors do
  allow do
    origins 'http://localhost:5173'
    resource '/*', headers: :any, methods: %i[get post put delete options]
  end
end

set :database_file, 'config/database.yml'

CODE_CHARS = [*'a'..'z', *'A'..'Z', *'0'..'9'].freeze
# Every real short code matches this. Anything else is rejected before it
# reaches Redis, Postgres or the logs.
CODE_FORMAT = /\A[a-zA-Z0-9]{7}\z/.freeze
CACHE_TTL = 86_400 # seconds (24 hours)

# Manages pooled Redis connections for the application.
module RedisPool
  def self.pool
    @pool ||= ConnectionPool.new(size: 16, timeout: 5) do
      Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
    end
  end

  # Runs the block with a pooled connection. Returns nil instead of raising
  # when Redis is unreachable, so callers can fall back to Postgres.
  def self.safely(&block)
    pool.with(&block)
  rescue Redis::BaseError, ConnectionPool::TimeoutError => e
    warn "redis unavailable: #{e.class}: #{e.message}"
    nil
  end

  # Drops the current pool; the next call to .pool builds a fresh one.
  def self.reset!
    @pool&.shutdown(&:close)
    @pool = nil
  end
end

# Rate limits per client IP. Counts live in Redis so every Puma worker shares them.
# Tests use an in-memory store so each test starts from zero.
Rack::Attack.cache.store =
  if ENV['RACK_ENV'] == 'test'
    ActiveSupport::Cache::MemoryStore.new
  else
    ActiveSupport::Cache::RedisCacheStore.new(redis: RedisPool.pool)
  end
Rack::Attack.throttled_response_retry_after_header = true

# Caddy sets X-Forwarded-For itself but passes a client's Forwarded header
# through untouched, and Rack would otherwise prefer Forwarded. Reading only
# X-Forwarded-For stops clients faking req.ip to dodge the limits.
Rack::Request.forwarded_priority = [:x_forwarded]

# The API itself, but not short codes that happen to start with "links".
API_PATH = %r{\A/links(?:/|\z)}.freeze

Rack::Attack.throttle('api/ip', limit: 60, period: 60) do |req|
  req.ip if API_PATH.match?(req.path)
end

Rack::Attack.throttle('redirect/ip', limit: 600, period: 60) do |req|
  req.ip if req.get? && !API_PATH.match?(req.path) && req.path != '/health'
end

# After Rack::Cors, so a 429 still carries CORS headers the dashboard can read.
use Rack::Attack

def generate_code(length = 7)
  Array.new(length) { CODE_CHARS.sample }.join
end

def valid_http_url?(value)
  uri = URI.parse(value)
  uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
rescue URI::InvalidURIError
  false
end

def cache_key(code)
  "link:#{code}"
end

def json_error(status, message)
  halt status, { error: message }.to_json
end

# Returns the URL, or halts with a JSON 400 if it is missing or not http(s).
def require_valid_url!(value)
  json_error 400, 'missing url' unless value
  json_error 400, 'invalid url' unless valid_http_url?(value)
  value
end

def authorized?
  expected = ENV['API_TOKEN'].to_s
  given = request.env['HTTP_AUTHORIZATION'].to_s.delete_prefix('Bearer ')
  !expected.empty? && Rack::Utils.secure_compare(given, expected)
end

before %r{/links(?:/.*)?} do
  json_error 401, 'unauthorized' unless authorized?
end

get '/links' do
  content_type :json
  Link.order(created_at: :desc).to_json
end

# Used by the deploy gate, site-health.sh and the GCP uptime check, so it must
# fail when the app cannot serve redirects, not just when Puma is down.
get '/health' do
  ActiveRecord::Base.connection_pool.with_connection { |conn| conn.select_value('SELECT 1') }
  RedisPool.pool.with(&:ping)
  'ok'
rescue StandardError => e
  warn "health check failed: #{e.class}: #{e.message}"
  halt 503, 'unhealthy'
end

get '/:code' do
  code = params['code']

  headers['Cache-Control'] = 'no-cache'
  halt 404, 'not found' unless CODE_FORMAT.match?(code)

  # Atomic increment on every redirect, cache hit or miss. Unknown codes match
  # no rows, so this is a no-op for them.
  Link.where(short_code: code).update_all('click_count = click_count + 1')

  cached_url = RedisPool.safely { |redis| redis.get(cache_key(code)) }
  if cached_url
    puts "cache HIT for #{code.inspect}"
  else
    puts "cache MISS for #{code.inspect}, querying postgres"
  end
  url = cached_url || Link.find_by(short_code: code)&.long_url

  # Checked on every redirect, cached or not, and before caching: Postgres or
  # Redis may hold a URL that never went through the API's validation.
  halt 404, 'not found' unless url && valid_http_url?(url)

  # nx: never overwrite a value written by PUT /links/:code. Without it, a
  # request that read the old row could re-cache the old URL after an update.
  RedisPool.safely { |redis| redis.set(cache_key(code), url, ex: CACHE_TTL, nx: true) } unless cached_url
  redirect url, 302
end

post '/links' do
  content_type :json
  long_url = require_valid_url!(params['url'])

  link = nil
  loop do
    link = Link.create!(short_code: generate_code, long_url: long_url)
    break
  rescue ActiveRecord::RecordNotUnique
    next
  end

  status 201
  link.to_json
end

put '/links/:code' do
  content_type :json
  code = params['code']
  link = Link.find_by(short_code: code)
  json_error 404, 'not found' unless link

  new_url = require_valid_url!(params['url'])

  link.update!(long_url: new_url)
  # Write the new URL instead of deleting the key, so a concurrent cache miss
  # (which uses nx: true) cannot put the old URL back.
  RedisPool.pool.with { |redis| redis.set(cache_key(code), new_url, ex: CACHE_TTL) }

  link.to_json
end
