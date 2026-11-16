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

  # Caddy overwrites X-Forwarded-For but passes a client's Forwarded header
  # through, so a faked Forwarded must not give each request a fresh limit.
  def test_faked_forwarded_header_does_not_bypass_limit
    61.times { |i| get '/links', {}, 'HTTP_FORWARDED' => "for=198.51.100.#{i}" }

    assert_equal 429, last_response.status
  end

  def test_each_real_client_gets_its_own_limit
    60.times { get '/links', {}, 'HTTP_X_FORWARDED_FOR' => '203.0.113.1' }
    get '/links', {}, 'HTTP_X_FORWARDED_FOR' => '203.0.113.2'

    assert_equal 200, last_response.status
  end

  def test_short_code_starting_with_links_gets_redirect_limit
    Link.create!(short_code: 'linksAB', long_url: 'https://example.com')

    capture_io { 61.times { get '/linksAB' } }

    assert_equal 302, last_response.status
  end

  # Sinatra decodes the path before routing, so /%6Cinks reaches the /links
  # routes. The throttles must see it as /links too.
  def test_percent_encoded_api_path_gets_api_limit
    60.times { get '/%6Cinks' }
    get '/%6Cinks'

    assert_equal 429, last_response.status
  end

  def test_percent_encoded_api_path_is_limited_for_writes
    61.times { post '/lin%6Bs', url: 'https://example.com' }

    assert_equal 429, last_response.status
  end
end
