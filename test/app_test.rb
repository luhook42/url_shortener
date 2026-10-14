# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require_relative '../app'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    header 'Host', 'localhost'
  end

  def test_health_returns_ok
    get '/health'
    assert_equal 200, last_response.status
    assert_equal 'ok', last_response.body
  end
end
