# frozen_string_literal: true

require_relative 'test_helper'

class SessionTest < AppTestCase
  PASSWORD = 'correct horse battery staple'

  def setup
    super
    header 'Authorization', nil # cookie only from here on
    User.create!(email: 'luke@example.com', password: PASSWORD)
  end

  def test_sign_in_sets_a_safe_session_cookie
    post '/session', email: 'Luke@Example.com', password: PASSWORD

    assert_equal 200, last_response.status
    cookie = last_response.headers['set-cookie']
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)

    get '/session'
    assert_equal 'luke@example.com', JSON.parse(last_response.body)['email']
  end

  def test_wrong_password_and_unknown_email_look_the_same
    post '/session', email: 'luke@example.com', password: 'wrong password'
    wrong_password = [last_response.status, last_response.body]

    post '/session', email: 'nobody@example.com', password: PASSWORD
    unknown_email = [last_response.status, last_response.body]

    assert_equal 401, wrong_password.first
    assert_equal wrong_password, unknown_email
  end

  def test_sign_out_ends_the_session
    post '/session', email: 'luke@example.com', password: PASSWORD
    delete '/session'
    get '/session'

    assert_equal 401, last_response.status
  end

  def test_edited_cookie_is_rejected
    set_cookie 'rack.session=forged-value'
    get '/session'

    assert_equal 401, last_response.status
  end
end
