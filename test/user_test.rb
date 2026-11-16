# frozen_string_literal: true

require_relative 'test_helper'

class UserTest < AppTestCase
  PASSWORD = 'correct horse battery staple'

  def test_password_is_never_stored
    user = User.create!(email: 'someone@example.com', password: PASSWORD)

    # Read the raw row, so the check doesn't depend on what the model exposes.
    row = ActiveRecord::Base.connection.select_one("SELECT * FROM users WHERE id = #{user.id.to_i}")

    row.each_value { |value| refute_includes value.to_s, PASSWORD }
    assert_match(/\A\$2[aby]\$/, row['password_digest'], 'should be a bcrypt hash')
  end

  def test_authenticate_checks_the_password
    user = User.create!(email: 'someone@example.com', password: PASSWORD)

    assert_equal user, user.authenticate(PASSWORD)
    refute user.authenticate('wrong password')
  end

  def test_password_is_required
    user = User.new(email: 'someone@example.com')

    refute user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  def test_email_is_stored_trimmed_and_lowercased
    user = User.create!(email: '  Someone@Example.COM ', password: PASSWORD)

    assert_equal 'someone@example.com', user.reload.email
  end

  def test_email_is_unique_regardless_of_case
    User.create!(email: 'someone@example.com', password: PASSWORD)
    duplicate = User.new(email: 'SOMEONE@example.com', password: PASSWORD)

    refute duplicate.valid?
    assert_includes duplicate.errors[:email], 'has already been taken'
  end

  # The unique index backs up the validation when two requests race past it.
  def test_database_rejects_duplicate_email
    User.create!(email: 'someone@example.com', password: PASSWORD)

    assert_raises(ActiveRecord::RecordNotUnique) do
      User.insert_all!([{ email: 'someone@example.com', password_digest: 'x' }])
    end
  end
end
