# frozen_string_literal: true

require_relative 'test_helper'

# Postgres or Redis can hold a URL that never went through the API's checks
# (a psql insert, a hand-edited cache key). Redirects must still refuse it.
class StoredUrlValidationTest < AppTestCase
  def test_bad_url_in_database_is_never_redirected_to
    Link.create!(short_code: 'xss0002', long_url: 'javascript:alert(document.domain)')

    get '/xss0002'

    assert_equal 404, last_response.status
    assert_nil last_response.headers['Location']
    assert_nil RedisPool.pool.with { |redis| redis.get('link:xss0002') }, 'a bad URL must never be cached'
  end

  def test_bad_url_in_cache_is_never_redirected_to
    RedisPool.safely { |redis| redis.set('link:abc1234', 'javascript:alert(1)') }

    get '/abc1234'

    assert_equal 404, last_response.status
    assert_nil last_response.headers['Location']
  end
end
