# frozen_string_literal: true

require 'connection_pool'
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

def generate_code(length = 7)
  Array.new(length) { CODE_CHARS.sample }.join
end

def valid_http_url?(value)
  uri = URI.parse(value)
  uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
rescue URI::InvalidURIError
  false
end

def authorized?
  expected = ENV['API_TOKEN'].to_s
  given = request.env['HTTP_AUTHORIZATION'].to_s.delete_prefix('Bearer ')
  !expected.empty? && Rack::Utils.secure_compare(given, expected)
end

before %r{/links(?:/.*)?} do
  halt 401, { error: 'unauthorized' }.to_json unless authorized?
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
  cache_key = "link:#{code}"

  headers['Cache-Control'] = 'no-cache'

  cached_url = RedisPool.safely { |redis| redis.get(cache_key) }
  if cached_url
    puts "cache HIT for #{code}"
    redirect cached_url, 302
  else
    puts "cache MISS for #{code}, querying postgres"
    link = Link.find_by(short_code: code)
    halt 404, 'not found' unless link

    # nx: never overwrite a value written by PUT /links/:code. Without it, a
    # request that read the old row could re-cache the old URL after an update.
    RedisPool.safely { |redis| redis.set(cache_key, link.long_url, ex: CACHE_TTL, nx: true) }
    redirect link.long_url, 302
  end
end

post '/links' do
  content_type :json
  long_url = params['url']
  halt 400, { error: 'missing url' }.to_json unless long_url
  halt 400, { error: 'invalid url' }.to_json unless valid_http_url?(long_url)

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
  halt 404, { error: 'not found' }.to_json unless link

  new_url = params['url']
  halt 400, { error: 'missing url' }.to_json unless new_url
  halt 400, { error: 'invalid url' }.to_json unless valid_http_url?(new_url)

  link.update!(long_url: new_url)
  # Write the new URL instead of deleting the key, so a concurrent cache miss
  # (which uses nx: true) cannot put the old URL back.
  RedisPool.pool.with { |redis| redis.set("link:#{code}", new_url, ex: CACHE_TTL) }

  link.to_json
end
