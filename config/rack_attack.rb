# frozen_string_literal: true

# Rate limits. Loaded by app.rb, which adds the middleware (use Rack::Attack)
# right after Rack::Cors.

# Counts live in Redis so every Puma worker shares them. Tests use an
# in-memory store, reset before each test, so each test starts from zero.
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

# Named checks for the throttles below. Rack::Attack builds one of these per
# request and passes it to every throttle, so the path is decoded once.
class Rack::Attack::Request < ::Rack::Request # rubocop:disable Style/ClassAndModuleChildren
  # The API itself, but not short codes that happen to start with "links".
  API_PATH = %r{\A/links(?:/|\z)}.freeze

  # Sinatra decodes the path before routing (/%6Cinks reaches the /links
  # routes), so the throttles decode it too or encoded paths dodge the limits.
  # .b keeps a bad encoding like /%ff from raising in the match.
  def decoded_path
    @decoded_path ||= Rack::Utils.unescape_path(path).b
  end

  def api?
    API_PATH.match?(decoded_path)
  end

  def health?
    decoded_path == '/health'
  end

  def sign_in?
    post? && decoded_path == '/session'
  end

  def redirect?
    get? && !api? && !health?
  end

  # Normalized like User#email, so case and spaces don't give fresh limits.
  # (Rack::Attack also does this by default; this keeps it true if that changes.)
  def sign_in_email
    params['email'].to_s.strip.downcase.presence
  end
end

# Per minute. Sign-in is the tightest because each guess costs a bcrypt check,
# and it's also limited per email so spreading guesses across IPs doesn't help.
Rack::Attack.throttle('api/ip',        limit: 60,  period: 60) { |req| req.ip if req.api? }
Rack::Attack.throttle('redirect/ip',   limit: 600, period: 60) { |req| req.ip if req.redirect? }
Rack::Attack.throttle('sign-in/ip',    limit: 10,  period: 60) { |req| req.ip if req.sign_in? }
Rack::Attack.throttle('sign-in/email', limit: 5,   period: 60) { |req| req.sign_in_email if req.sign_in? }
