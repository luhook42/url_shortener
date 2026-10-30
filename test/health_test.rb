# frozen_string_literal: true

require_relative 'test_helper'

class HealthTest < AppTestCase
  def test_health_fails_when_redis_is_unreachable
    original = RedisPool.instance_variable_get(:@pool)
    RedisPool.instance_variable_set(:@pool, ConnectionPool.new(size: 1) { Redis.new(url: 'redis://127.0.0.1:1') })
    get '/health'

    assert_equal 503, last_response.status
    refute_includes last_response.body, 'ok'
  ensure
    RedisPool.instance_variable_set(:@pool, original)
  end
end
