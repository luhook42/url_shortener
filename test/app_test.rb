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

  def test_unknown_code_returns404
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

  def test_create_rejects_missing_url
    post '/links'

    assert_equal 400, last_response.status
    assert_equal 0, Link.count
  end

  def test_create_rejects_non_http_urls
    ['foo', 'javascript:alert(1)', 'ftp://example.com', 'http://'].each do |bad|
      post '/links', url: bad

      assert_equal 400, last_response.status, "expected 400 for #{bad}"
    end
    assert_equal 0, Link.count
  end

  def test_update_rejects_invalid_url
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    put '/links/abc1234', url: 'javascript:alert(1)'

    assert_equal 400, last_response.status
    assert_equal 'https://example.com', Link.find_by(short_code: 'abc1234').long_url
  end

  def test_update_unknown_code_returns404
    put '/links/nope123', url: 'https://example.com'

    assert_equal 404, last_response.status
  end

  def test_create_requires_token
    header 'Authorization', ''
    post '/links', url: 'https://example.com'

    assert_equal 401, last_response.status
    assert_equal 0, Link.count
  end

  def test_update_rejects_wrong_token
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    header 'Authorization', 'Bearer wrong'
    put '/links/abc1234', url: 'https://evil.example.com'

    assert_equal 401, last_response.status
    assert_equal 'https://example.com', Link.find_by(short_code: 'abc1234').long_url
  end

  def test_list_requires_token
    header 'Authorization', ''
    get '/links'

    assert_equal 401, last_response.status
  end

  def test_redirect_and_health_stay_public
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    header 'Authorization', ''
    get '/abc1234'
    assert_equal 302, last_response.status

    get '/health'
    assert_equal 200, last_response.status
  end

  def test_cached_redirect_has_expiry
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    get '/abc1234'

    ttl = RedisPool.pool.with { |redis| redis.ttl('link:abc1234') }
    assert_operator ttl, :>, 0
    assert_operator ttl, :<=, 86_400
  end
end
