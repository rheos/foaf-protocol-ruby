# Named Foaf::TrustlineRecord to avoid collision with Foaf::Trustline protocol module.
# This is the ActiveRecord model — persistence and querying.

module Foaf
  class TrustlineRecord < ApplicationRecord
    self.table_name = "trustlines"

    belongs_to :currency_network
    has_many :trustline_update_requests, foreign_key: :trustline_id, dependent: :destroy
    has_many :trustline_events, through: :currency_network

    # === VALIDATIONS ===
    validates :user_a_address, presence: true
    validates :user_b_address, presence: true
    validates :creditline_given, numericality: { greater_than_or_equal_to: 0 }
    validates :creditline_received, numericality: { greater_than_or_equal_to: 0 }
    validate :canonical_user_order
    validate :different_users

    # === SCOPES ===
    scope :active, -> { where(is_frozen: false) }
    scope :for_address, ->(addr) { where("user_a_address = ? OR user_b_address = ?", addr, addr) }
    scope :in_network, ->(network_id) { where(currency_network_id: network_id) }
    scope :between, ->(addr1, addr2) {
      a, b = [addr1, addr2].sort
      where(user_a_address: a, user_b_address: b)
    }

    # Which side of the trustline is this address?
    def user_is_a?(address)
      user_a_address == address
    end

    # The other address on this trustline.
    def counterparty(address)
      user_is_a?(address) ? user_b_address : user_a_address
    end

    private

    def canonical_user_order
      return unless user_a_address.present? && user_b_address.present?
      if user_a_address >= user_b_address
        errors.add(:base, "user_a_address must be less than user_b_address (canonical ordering)")
      end
    end

    def different_users
      if user_a_address == user_b_address
        errors.add(:base, "Cannot create trustline with self")
      end
    end
  end
end
