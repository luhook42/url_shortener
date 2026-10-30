# frozen_string_literal: true

require_relative 'test_helper'

class RedisFallbackTest < AppTestCase
  def test_redirect_falls_back_to_postgres_when_redis_is_down
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    with_unreachable_redis { get '/abc1234' }

    assert_equal 302, last_response.status
    assert_equal 'https://example.com', last_response.headers['Location']
  end

  private

  def with_unreachable_redis
    original = RedisPool.instance_variable_get(:@pool)
    RedisPool.instance_variable_set(:@pool, ConnectionPool.new(size: 1) { Redis.new(url: 'redis://127.0.0.1:1') })
    yield
  ensure
    RedisPool.instance_variable_set(:@pool, original)
  end
end
