# frozen_string_literal: true

require_relative 'test_helper'

class ClickCountTest < AppTestCase
  def test_redirects_increment_click_count_on_miss_and_hit
    Link.create!(short_code: 'abc1234', long_url: 'https://example.com')

    get '/abc1234' # cache miss
    get '/abc1234' # cache hit

    assert_equal 302, last_response.status
    assert_equal 2, Link.find_by(short_code: 'abc1234').click_count
  end

  def test_unknown_code_runs_no_update
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      statements << payload[:sql]
    end

    capture_io { get '/nope123' }

    assert_equal 404, last_response.status
    assert_empty statements.grep(/\AUPDATE/i), 'junk codes should cost a lookup, not a write'
    refute_empty statements.grep(/\ASELECT/i), 'sanity check: the subscriber saw the lookup'
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
