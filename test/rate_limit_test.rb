# frozen_string_literal: true

require_relative 'test_helper'

# Rack::Attack limits per client IP (see the throttles in app.rb).
class RateLimitTest < AppTestCase
  def test_api_is_rate_limited_per_ip
    60.times { get '/links' }
    get '/links'

    assert_equal 429, last_response.status
    refute_nil last_response.headers['Retry-After']
  end

  def test_redirects_are_rate_limited_per_ip
    capture_io { 600.times { get '/nope123' } }
    get '/nope123'

    assert_equal 429, last_response.status
  end

  def test_health_is_never_rate_limited
    700.times { get '/health' }

    assert_equal 200, last_response.status
  end
end
