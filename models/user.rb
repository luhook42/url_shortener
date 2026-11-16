# frozen_string_literal: true

# An account that can sign in. Only a bcrypt hash of the password is stored.
class User < ActiveRecord::Base
  has_secure_password
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true
end
