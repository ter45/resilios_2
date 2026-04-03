class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  self.implicit_order_column = "created_at"
  before_create :set_ulid_primary_key

  private

  def set_ulid_primary_key
    self.id ||= generate_ulid
  end

  ENCODING = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze

  def generate_ulid
    t = (Time.now.to_f * 1000).to_i
    encode_time(t) + encode_random(16)
  end

  def encode_time(time_ms)
    result = []
    mod = time_ms
    10.times do
      result.unshift ENCODING[mod & 31]
      mod >>= 5
    end
    result.join
  end

  def encode_random(length)
    length.times.map { ENCODING[SecureRandom.random_number(32)] }.join
  end
end
