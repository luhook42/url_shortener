# frozen_string_literal: true

require_relative 'test_helper'

# A signed-in browser sends the session cookie with every request, so only the
# dashboard's origin may use it to change things.
class CsrfTest < AppTestCase
  PASSWORD = 'correct horse battery staple'

  def setup
    super
    header 'Authorization', nil # cookie only, like a browser
    User.create!(email: 'luke@example.com', password: PASSWORD)
    post '/session', email: 'luke@example.com', password: PASSWORD
  end

  def test_the_dashboard_can_create_a_link_with_the_session
    post '/links', { url: 'https://example.com' }, 'HTTP_ORIGIN' => 'http://localhost:5173'

    assert_equal 201, last_response.status
  end

  # localhost:5050 is the same *site* as the API, so SameSite=Lax still sends
  # the cookie. The Origin check is what stops it.
  def test_another_origin_cannot_use_the_session
    post '/links', { url: 'https://evil.example' }, 'HTTP_ORIGIN' => 'http://localhost:5050'

    assert_equal 401, last_response.status
    assert_equal 0, Link.count
  end
end
