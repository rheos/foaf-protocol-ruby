class TrustlineUpdateRequest < ApplicationRecord
  belongs_to :trustline, class_name: "Foaf::TrustlineRecord"

  validates :initiator_address, presence: true
  validates :creditline_given, numericality: { greater_than_or_equal_to: 0 }
  validates :creditline_received, numericality: { greater_than_or_equal_to: 0 }
end
