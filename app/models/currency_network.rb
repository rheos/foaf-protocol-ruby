class CurrencyNetwork < ApplicationRecord
  has_many :trustlines, dependent: :restrict_with_error
  has_many :operations, dependent: :restrict_with_error
  has_many :trustline_events, dependent: :restrict_with_error
  has_many :pending_transfers, dependent: :restrict_with_error

  validates :address, presence: true, uniqueness: true
  validates :name, presence: true
  validates :symbol, presence: true, uniqueness: true
  validates :decimals, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :capacity_imbalance_fee_divisor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_hops, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(is_frozen: false) }

  def frozen?
    is_frozen
  end
end
