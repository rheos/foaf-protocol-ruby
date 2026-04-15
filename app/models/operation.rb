class Operation < ApplicationRecord
  belongs_to :currency_network, optional: true
  has_many :trustline_events, dependent: :restrict_with_error

  validates :operation_type, presence: true
  validates :module_name, presence: true
  validates :actor_address, presence: true
  validates :inputs, presence: true
  validates :status, presence: true, inclusion: { in: %w[applied failed pending] }

  scope :for_actor, ->(address) { where(actor_address: address) }
  scope :for_network, ->(network_id) { where(currency_network_id: network_id) }
  scope :applied, -> { where(status: "applied") }
end
