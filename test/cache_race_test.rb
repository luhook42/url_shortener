# frozen_string_literal: true

require_relative 'test_helper'

class CacheRaceTest < AppTestCase
  def test_update_overwrites_cached_url
    Link.create!(short_code: 'abc1234', long_url: 'https://old.example.com')
    get '/abc1234'

    put '/links/abc1234', url: 'https://new.example.com'

    assert_equal 'https://new.example.com', cached('abc1234')
  end

  def test_slow_cache_miss_does_not_recache_old_url_after_update
    Link.create!(short_code: 'abc1234', long_url: 'https://old.example.com')

    # The miss reads the old row, then the update lands before the miss writes the cache.
    update_during_lookup { put '/links/abc1234', url: 'https://new.example.com' }
    get '/abc1234'

    assert_equal 'https://new.example.com', cached('abc1234')
  end

  private

  def update_during_lookup(&update)
    stale = Link.find_by(short_code: 'abc1234')
    Link.define_singleton_method(:find_by) do |*|
      singleton_class.remove_method(:find_by)
      update.call
      stale
    end
  end

  def cached(code)
    RedisPool.pool.with { |redis| redis.get("link:#{code}") }
  end
end
