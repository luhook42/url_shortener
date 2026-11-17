# frozen_string_literal: true

ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://localhost:6379/1'
ENV['API_TOKEN'] = 'test-token'
ENV['SESSION_SECRET'] = 'test-secret-' * 8

require 'minitest/autorun'
require 'rack/test'
require_relative '../app'

class AppTestCase < Minitest::Test
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
    header 'Authorization', 'Bearer test-token'
  end

  # The Set-Cookie line for one cookie (a response can set several).
  def cookie_named(name)
    Array(last_response.headers['set-cookie']).find { |c| c.start_with?("#{name}=") }
  end
end
