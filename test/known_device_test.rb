# frozen_string_literal: true

require 'active_support/testing/time_helpers'
require_relative 'test_helper'

# Someone who knows your email can use up its sign-in limit. A browser you've
# signed in with before skips that limit, so they can't lock you out.
class KnownDeviceTest < AppTestCase
  include ActiveSupport::Testing::TimeHelpers

  PASSWORD = 'correct horse battery staple'
  OWNER_IP = { 'HTTP_X_FORWARDED_FOR' => '198.51.100.1' }.freeze

  def setup
    super
    header 'Authorization', nil
    User.create!(email: 'luke@example.com', password: PASSWORD)
    User.create!(email: 'other@example.com', password: PASSWORD)
  end

  def test_owner_on_a_known_device_is_not_locked_out
    sign_in_as_owner
    use_up_email_limit('luke@example.com')

    owner_signs_in

    assert_equal 200, last_response.status
  end

  def test_a_new_device_is_still_limited
    use_up_email_limit('luke@example.com')

    owner_signs_in

    assert_equal 429, last_response.status
  end

  def test_device_cookie_only_counts_for_its_own_email
    sign_in_as_owner
    use_up_email_limit('other@example.com')

    post '/session', { email: 'other@example.com', password: PASSWORD }, OWNER_IP

    assert_equal 429, last_response.status
  end

  def test_known_device_has_its_own_limit
    sign_in_as_owner
    5.times { |i| post '/session', { email: 'luke@example.com', password: 'wrong' }, ip(i) }
    post '/session', { email: 'luke@example.com', password: PASSWORD }, ip(99)

    assert_equal 429, last_response.status
  end

  # Every sign-in mints a new token, so someone who once had the password could
  # collect many. Changing the password must make all of them useless.
  def test_device_tokens_stop_working_when_the_password_changes
    sign_in_as_owner
    User.find_by(email: 'luke@example.com').update!(password: 'a brand new long password')
    use_up_email_limit('luke@example.com')

    post '/session', { email: 'luke@example.com', password: 'a brand new long password' }, OWNER_IP

    assert_equal 429, last_response.status
  end

  def test_forged_device_cookie_does_not_help
    use_up_email_limit('luke@example.com')
    set_cookie "#{KnownDevice::COOKIE}=deadbeef.deadbeef; path=/session"

    owner_signs_in

    assert_equal 429, last_response.status
  end

  # The browser drops the cookie at its Expires, but a copied token could be
  # replayed without one, so the server checks the expiry inside the token.
  def test_device_token_expires_after_ninety_days
    sign_in_as_owner
    token = cookie_named(KnownDevice::COOKIE)[/\A[^;]+/]
    travel 91.days
    use_up_email_limit('luke@example.com')

    clear_cookies
    set_cookie "#{token}; path=/session"
    owner_signs_in

    assert_equal 429, last_response.status
  end

  def test_device_cookie_survives_sign_out
    sign_in_as_owner
    delete '/session'
    use_up_email_limit('luke@example.com')

    owner_signs_in

    assert_equal 200, last_response.status
  end

  def test_device_cookie_is_narrow_and_reveals_nothing
    sign_in_as_owner
    cookie = cookie_named(KnownDevice::COOKIE)

    assert_match(%r{path=/session}i, cookie)
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)
    refute_includes cookie, 'luke@example.com'
    refute_includes cookie, 'luke@example.com'.unpack1('H*')
  end

  private

  def sign_in_as_owner
    owner_signs_in
    assert_equal 200, last_response.status
  end

  def owner_signs_in
    post '/session', { email: 'luke@example.com', password: PASSWORD }, OWNER_IP
  end

  # From other IPs, in a separate browser with none of the owner's cookies.
  def use_up_email_limit(email)
    with_session(:attacker) do
      5.times { |i| post '/session', { email: email, password: 'wrong' }, ip(i) }
    end
  end

  def ip(index)
    { 'HTTP_X_FORWARDED_FOR' => "203.0.113.#{index}" }
  end
end
