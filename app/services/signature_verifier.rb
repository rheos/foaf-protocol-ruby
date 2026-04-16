# frozen_string_literal: true

# Verifies secp256k1 signatures on operations.
# This is the protocol's auth layer — identical to how blockchain nodes verify transactions.
# No passwords, no sessions, no JWT. Just cryptographic proof.

class SignatureVerifier
  # Verify that a payload was signed by the holder of the given address.
  #
  # @param payload [String] the signed data (JSON-encoded operation)
  # @param signature [String] hex-encoded secp256k1 signature
  # @param address [String] expected signer address (0x-prefixed)
  # @return [Boolean] true if signature is valid for this address
  def self.verify(payload:, signature:, address:)
    return false if signature.blank? || address.blank?

    recovered_key = Eth::Key.personal_recover(payload, signature)
    recovered_address = Eth::Util.public_key_to_address(recovered_key).to_s
    recovered_address.downcase == address.downcase
  rescue StandardError
    false
  end

  # Generate a new keypair. Used by consuming apps, not by FOAF itself.
  # Provided as a convenience for testing and onboarding.
  #
  # @return [Hash] { address:, public_key:, private_key: }
  def self.generate_keypair
    key = Eth::Key.new
    {
      address: key.address.to_s,
      public_key: key.public_hex,
      private_key: key.private_hex
    }
  end

  # Sign a payload with a private key. Used for testing only.
  # In production, the consuming app handles signing.
  #
  # @param payload [String] data to sign
  # @param private_key [String] hex-encoded private key
  # @return [String] hex-encoded signature
  def self.sign(payload:, private_key:)
    key = Eth::Key.new(priv: private_key)
    key.personal_sign(payload)
  end
end
