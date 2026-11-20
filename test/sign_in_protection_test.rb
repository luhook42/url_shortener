# frozen_string_literal: true

require_relative 'test_helper'

# Rate limits on POST /session, and the CORS settings the dashboard needs to
# sign in with a cookie.
class SignInProtectionTest < AppTestCase
  def setup
    super
    header 'Authorization', nil
  end

  def test_sign_in_is_limited_per_ip
    10.times { |i| post '/session', email: "guess#{i}@example.com", password: 'wrong' }
    post '/session', email: 'another@example.com', password: 'wrong'

    assert_equal 429, last_response.status
    refute_nil last_response.headers['Retry-After']
  end

  # Spreading guesses for one account across many IPs doesn't help, and
  # changing the case or adding spaces doesn't give a fresh limit.
  def test_sign_in_is_limited_per_email
    ['victim@example.com', 'VICTIM@example.com', ' victim@example.com ', 'Victim@Example.com', 'victim@EXAMPLE.com']
      .each_with_index do |email, i|
        post '/session', { email: email, password: 'wrong' }, 'HTTP_X_FORWARDED_FOR' => "203.0.113.#{i}"
      end
    post '/session', { email: 'victim@example.com', password: 'wrong' }, 'HTTP_X_FORWARDED_FOR' => '203.0.113.99'

    assert_equal 429, last_response.status
  end

  def test_malformed_sign_in_body_does_not_crash_the_limiter
    post '/session', 'email[a]=1&email=2', 'CONTENT_TYPE' => 'application/x-www-form-urlencoded'

    refute_equal 500, last_response.status
  end

  def test_dashboard_may_send_the_session_cookie
    options '/session', {}, 'HTTP_ORIGIN' => 'http://localhost:5173', 'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST'

    assert_equal 'http://localhost:5173', last_response.headers['access-control-allow-origin']
    assert_equal 'true', last_response.headers['access-control-allow-credentials']
  end

  def test_other_sites_may_not
    options '/session', {}, 'HTTP_ORIGIN' => 'https://evil.example', 'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST'

    assert_nil last_response.headers['access-control-allow-origin']
    assert_nil last_response.headers['access-control-allow-credentials']
  end
end
