# frozen_string_literal: true

require 'json'
require_relative 'test_helper'

class AppTest < AppTestCase
  def test_health_returns_ok
    get '/health'
    assert_equal 200, last_response.status
    assert_equal 'ok', last_response.body
  end

  def test_create_link_saves_and_returns_it
    post 'links', url: 'https://example.com'

    assert_equal 201, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 'https://example.com', body['long_url']
    assert_equal 7, body['short_code'].length
    assert_equal 1, Link.count
  end

  def test_redirect_goes_to_long_url
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    get '/abc1234'

    assert_equal 302, last_response.status
    assert_equal 'https://example.com', last_response.headers['Location']
    assert_equal 'no-cache', last_response.headers['Cache-Control']
  end

  def test_unknown_code_returns_404
    get '/nope123'

    assert_equal 404, last_response.status
  end

  def test_update_clears_cached_redirect
    Link.create!(short_code: 'abc1234', long_url: 'https://old.example.com')

    get '/abc1234'
    assert_equal 'https://old.example.com', last_response.headers['Location']

    put '/links/abc1234', url: 'https://new.example.com'
    assert_equal 200, last_response.status

    get '/abc1234'
    assert_equal 'https://new.example.com', last_response.headers['Location']
  end
end
