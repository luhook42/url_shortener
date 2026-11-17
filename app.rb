# frozen_string_literal: true

require 'active_support'
require 'active_support/cache'
require 'bcrypt'
require 'connection_pool'
require 'rack/attack'
require 'rack/cors'
require 'redis'
require 'securerandom'
require 'sinatra'
require 'sinatra/activerecord'
require 'uri'
require_relative 'models/link'
require_relative 'models/user'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

set :database_file, 'config/database.yml'

# Sessions: an encrypted, signed cookie holding only the signed-in user's id.
# Required in production. Elsewhere a random one is fine; sessions just reset
# on restart. (rake loads this file too, so tests and CI need no secret.)
set :session_secret, ENV.fetch('SESSION_SECRET') {
  abort 'SESSION_SECRET is not set.' if production?
  SecureRandom.hex(64)
}
# rack-session only checks the length on the first request, which would make
# every request (including /health) fail. Fail at boot with a clear message.
if settings.session_secret.bytesize < 64
  abort 'SESSION_SECRET must be at least 64 bytes. Generate one with: ' \
        "ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'"
end
# The cookie's expiry only tells the browser when to drop it, and is pushed
# back on every request, so current_user also checks the time since sign-in.
SESSION_TTL = 8 * 60 * 60 # seconds (8 hours)
set :sessions,
    httponly: true,              # page JavaScript can't read it, so XSS can't steal it
    secure: production?,         # only sent over HTTPS in production
    same_site: :lax,             # not sent on most cross-site requests (CSRF defense)
    expire_after: SESSION_TTL    # signed out after 8 hours

# Compared against when an email doesn't exist, so a wrong email takes as long
# as a wrong password and the response time doesn't reveal which emails exist.
DUMMY_DIGEST = BCrypt::Password.create(SecureRandom.hex(32))

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

# ---------------------------------------------------------------------------
# Middleware (runs in the order it is added, outermost first)
# ---------------------------------------------------------------------------

use Rack::Cors do
  allow do
    origins 'http://localhost:5173'
    # credentials: the browser sends and keeps the session cookie on the
    # dashboard's requests. Only safe because origins is an exact list.
    resource '/*', headers: :any, methods: %i[get post put delete options], credentials: true
  end
end

# Rate limits per client IP: see config/rack_attack.rb.
require_relative 'config/rack_attack'

# After Rack::Cors, so a 429 still carries CORS headers the dashboard can read.
use Rack::Attack

# ---------------------------------------------------------------------------
# Plain functions (no request needed; the Rakefile uses generate_code too)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Request helpers (use the current request, so they only work inside routes)
# ---------------------------------------------------------------------------

helpers do
  def authorized?
    expected = ENV['API_TOKEN'].to_s
    given = request.env['HTTP_AUTHORIZATION'].to_s.delete_prefix('Bearer ')
    !expected.empty? && Rack::Utils.secure_compare(given, expected)
  end

  # The signed-in user, or nil. The cookie lives in the browser, so a copy of
  # it would otherwise work forever: the session must be under SESSION_TTL old,
  # and its session_version must still match (sign-out bumps it).
  def current_user
    return @current_user if defined?(@current_user)

    signed_in_at = session[:signed_in_at].to_i
    @current_user =
      if session[:user_id] && Time.now.to_i - signed_in_at < SESSION_TTL
        User.find_by(id: session[:user_id], session_version: session[:session_version])
      end
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
end

# ---------------------------------------------------------------------------
# Routes. Order matters: Sinatra uses the first match, and get '/:code' would
# also match /links and /health, so it must stay last.
# ---------------------------------------------------------------------------

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

# --- Links API (token required) ---

before %r{/links(?:/.*)?} do
  json_error 401, 'unauthorized' unless authorized?
end

get '/links' do
  content_type :json
  Link.order(created_at: :desc).to_json
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

# --- Sign in / sign out (session cookie) ---
# Before get '/:code': "session" is seven letters, so it matches CODE_FORMAT.

post '/session' do
  content_type :json
  user = User.find_by(email: params['email'].to_s)
  password = params['password'].to_s

  # Same work and same answer whether the email exists or not.
  ok = user ? user.authenticate(password) : (BCrypt::Password.new(DUMMY_DIGEST).is_password?(password) && false)
  json_error 401, 'invalid email or password' unless ok

  session.clear # a fresh session on sign-in, never one that existed before
  session[:user_id] = user.id
  session[:session_version] = user.session_version
  session[:signed_in_at] = Time.now.to_i
  { email: user.email }.to_json
end

get '/session' do
  content_type :json
  json_error 401, 'not signed in' unless current_user
  { email: current_user.email }.to_json
end

delete '/session' do
  # Ends every session for this user, including any copy of this cookie.
  User.update_counters(current_user.id, session_version: 1) if current_user
  session.clear
  status 204
end

# --- Redirects (public, must stay last) ---

get '/:code' do
  code = params['code']

  headers['Cache-Control'] = 'no-cache'
  halt 404, 'not found' unless code.valid_encoding? && CODE_FORMAT.match?(code)

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

  # Atomic increment, cache hit or miss. It runs only once the code is known to
  # exist, so a junk code costs one indexed lookup and no write.
  Link.where(short_code: code).update_all('click_count = click_count + 1')

  # nx: never overwrite a value written by PUT /links/:code. Without it, a
  # request that read the old row could re-cache the old URL after an update.
  RedisPool.safely { |redis| redis.set(cache_key(code), url, ex: CACHE_TTL, nx: true) } unless cached_url
  redirect url, 302
end
