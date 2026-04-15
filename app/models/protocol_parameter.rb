class ProtocolParameter < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.get(key, default: nil)
    find_by(key: key)&.value || default
  end

  def to_i
    value.to_i
  end

  def to_f
    value.to_f
  end
end
