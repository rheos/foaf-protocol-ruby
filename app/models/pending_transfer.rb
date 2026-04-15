class PendingTransfer < ApplicationRecord
  belongs_to :currency_network

  validates :from_address, presence: true
  validates :to_address, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending confirmed rejected cancelled] }
  validates :fee_payer, inclusion: { in: %w[sender receiver] }

  scope :pending, -> { where(status: "pending") }
  scope :for_address, ->(addr) { where("from_address = ? OR to_address = ?", addr, addr) }
  scope :incoming_for, ->(addr) { where(to_address: addr, status: "pending") }
  scope :outgoing_for, ->(addr) { where(from_address: addr, status: "pending") }

  def pending?
    status == "pending"
  end
end
