# frozen_string_literal: true

require 'active_support/testing/time_helpers'
require_relative 'test_helper'

# The session cookie is stored in the browser, so the server has to decide when
# one stops working: after sign-out (even for a copy of the cookie), and 8
# hours after sign-in however often it's used.
class SessionRevocationTest < AppTestCase
  include ActiveSupport::Testing::TimeHelpers

  PASSWORD = 'correct horse battery staple'

  def setup
    super
    header 'Authorization', nil
    User.create!(email: 'luke@example.com', password: PASSWORD)
  end

  def teardown
    travel_back
  end

  def test_copied_cookie_stops_working_after_sign_out
    stolen = sign_in
    delete '/session'

    clear_cookies
    set_cookie stolen
    get '/session'

    assert_equal 401, last_response.status
  end

  def test_signing_in_again_after_sign_out_works
    sign_in
    delete '/session'
    sign_in
    get '/session'

    assert_equal 200, last_response.status
  end

  def test_session_lasts_up_to_eight_hours
    sign_in
    travel 7.hours + 59.minutes
    get '/session'

    assert_equal 200, last_response.status
  end

  # Using the session keeps refreshing the cookie's expiry in the browser, so
  # the server must count from sign-in, not from the last request.
  def test_session_ends_eight_hours_after_sign_in_even_if_used
    sign_in
    4.times do
      travel 2.hours + 1.minute
      get '/session'
    end

    assert_equal 401, last_response.status
  end

  private

  def sign_in
    post '/session', email: 'luke@example.com', password: PASSWORD
    assert_equal 200, last_response.status
    cookie_named('rack.session')[/\Arack\.session=[^;]+/]
  end
end
