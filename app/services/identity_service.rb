# frozen_string_literal: true

# Identity registration.
# An identity is just a public key — like an Ethereum address existing on-chain
# the moment someone sends it ETH. Here we register it explicitly so we can
# look it up and verify signatures against it.

class IdentityService
  # Register a new identity (public key).
  #
  # @param public_key [String] hex-encoded secp256k1 public key
  # @return [Identity]
  def self.register(public_key:)
    address = derive_address(public_key)

    Identity.create!(
      address: address,
      public_key: public_key
    )
  end

  # Find an identity by address.
  def self.find_by_address(address)
    Identity.find_by(address: address.downcase)
  end

  # Check if an identity exists.
  def self.exists?(address)
    Identity.exists?(address: address.downcase)
  end

  private

  # Derive an Ethereum-compatible address from a public key.
  def self.derive_address(public_key)
    Eth::Util.public_key_to_address(Eth::Util.hex_to_bin(public_key)).to_s.downcase
  rescue StandardError
    # Fallback: hash the key to get a deterministic address
    "0x#{Digest::SHA256.hexdigest(public_key)[0..39]}"
  end
end
