class TrustlineEvent < ApplicationRecord
  belongs_to :operation
  belongs_to :currency_network

  VALID_TYPES = %w[
    Transfer
    TrustlineUpdate
    TrustlineUpdateRequest
    TrustlineUpdateCancel
    BalanceUpdate
  ].freeze

  validates :event_type, presence: true, inclusion: { in: VALID_TYPES }
  validates :from_address, presence: true
  validates :to_address, presence: true

  scope :for_address, ->(addr) { where("from_address = ? OR to_address = ?", addr, addr) }
  scope :in_network, ->(network_id) { where(currency_network_id: network_id) }
  scope :of_type, ->(type) { where(event_type: type) }
  scope :recent, -> { order(created_at: :desc) }
end
