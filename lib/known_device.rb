# frozen_string_literal: true

require 'json'
require 'openssl'
require 'rack/utils'
require 'securerandom'

# A signed cookie that marks a browser as having signed in to an account
# before. Such browsers skip the per-email sign-in limit, so someone else
# using that limit up can't lock the account's owner out.
#
# The token holds HMACs of the email and of the account's password hash (not
# either value itself), a random device id, and an expiry, signed with a key
# derived from SESSION_SECRET. Tying it to the password hash means changing the
# password makes every existing token useless, however many were collected.
class KnownDevice
  COOKIE = 'known_device'
  TTL = 90 * 24 * 60 * 60 # seconds (90 days)

  def initialize(secret)
    @key = OpenSSL::HMAC.digest('SHA256', secret, 'known-device')
  end

  def token_for(user)
    payload = [account_digest(user.email, user.password_digest), SecureRandom.hex(16), Time.now.to_i + TTL]
    data = JSON.generate(payload).unpack1('H*')
    "#{data}.#{sign(data)}"
  end

  # The device id, if the token is genuine, unexpired, and for this account
  # with its current password.
  def device_id(token, user)
    data, signature = token.to_s.split('.', 2)
    return unless user && data && signature && Rack::Utils.secure_compare(sign(data), signature)

    digest, id, expires_at = JSON.parse([data].pack('H*'))
    id if expires_at > Time.now.to_i &&
          Rack::Utils.secure_compare(digest, account_digest(user.email, user.password_digest))
  end

  private

  def sign(data)
    OpenSSL::HMAC.hexdigest('SHA256', @key, data)
  end

  def account_digest(email, password_digest)
    OpenSSL::HMAC.hexdigest('SHA256', @key, JSON.generate([email, password_digest]))
  end
end
