class ApiKey < ApplicationRecord
  HMAC_SECRET_KEY = Rails.application.credentials.api_key_hmac_secret_key

  belongs_to :bearer, polymorphic: true

  before_create :generate_raw_token
  before_create :generate_token_digest

  # Attribute for storing and accessing the raw (non-hashed)
  # token value directly after creation
  attr_accessor :raw_token

  def self.find_by_token!(token)
    find_by!(token_digest: generate_digest(token))
  end

  def self.find_by_token(token)
    find_by(token_digest: generate_digest(token))
  end

  def self.generate_digest(token)
    OpenSSL::HMAC.hexdigest("SHA256", HMAC_SECRET_KEY, token)
  end

  private

  def generate_raw_token
    self.raw_token = SecureRandom.base58(30)
  end

  def generate_token_digest
    self.token_digest = self.class.generate_digest(raw_token)
  end
end
