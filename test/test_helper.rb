# frozen_string_literal: true

ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://localhost:6379/1'
ENV['API_TOKEN'] = 'test-token'
ENV['SESSION_SECRET'] = 'test-secret-' * 8

require 'active_support/testing/time_helpers'
require 'minitest/autorun'
require 'rack/test'

# bcrypt is deliberately slow (about 0.25 s per hash). Tests use the minimum
# cost so they stay fast; production keeps the default. Set before app.rb
# loads, because app.rb builds DUMMY_DIGEST at load time.
require 'bcrypt'
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
require_relative '../app'

class AppTestCase < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    Link.delete_all
    User.delete_all
    RedisPool.pool.with(&:flushdb)
    # Rate-limit counters share one in-memory store for the whole run. Without
    # this, requests add up across tests and random ones start getting 429s.
    Rack::Attack.reset!
    # Rack::Attack counts in fixed windows (e.g. each clock minute). A test whose
    # requests cross a window edge would see its count reset and randomly miss a
    # 429, so the clock stands still unless a test moves it with travel.
    freeze_time
    header 'Authorization', 'Bearer test-token'
  end

  # The Set-Cookie line for one cookie (a response can set several).
  def cookie_named(name)
    Array(last_response.headers['set-cookie']).find { |c| c.start_with?("#{name}=") }
  end
end
