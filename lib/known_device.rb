# frozen_string_literal: true

require 'json'
require 'openssl'
require 'rack/utils'
require 'securerandom'

# A signed cookie that marks a browser as having signed in to an account
# before. Such browsers skip the per-email sign-in limit, so someone else
# using that limit up can't lock the account's owner out.
#
# The token holds an HMAC of the email (not the email itself), a random
# device id, and an expiry, signed with a key derived from SESSION_SECRET.
class KnownDevice
  COOKIE = 'known_device'
  TTL = 90 * 24 * 60 * 60 # seconds (90 days)

  def initialize(secret)
    @key = OpenSSL::HMAC.digest('SHA256', secret, 'known-device')
  end

  def token_for(email)
    data = JSON.generate([email_digest(email), SecureRandom.hex(16), Time.now.to_i + TTL]).unpack1('H*')
    "#{data}.#{sign(data)}"
  end

  # The device id, if the token is genuine, unexpired and for this email.
  def device_id(token, email)
    data, signature = token.to_s.split('.', 2)
    return unless data && signature && Rack::Utils.secure_compare(sign(data), signature)

    digest, id, expires_at = JSON.parse([data].pack('H*'))
    id if expires_at > Time.now.to_i && Rack::Utils.secure_compare(digest, email_digest(email))
  end

  private

  def sign(data)
    OpenSSL::HMAC.hexdigest('SHA256', @key, data)
  end

  def email_digest(email)
    OpenSSL::HMAC.hexdigest('SHA256', @key, "email:#{email}")
  end
end
