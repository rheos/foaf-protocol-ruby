# frozen_string_literal: true

# Verifies secp256k1 signatures on operations.
# This is the protocol's auth layer — identical to how blockchain nodes verify transactions.
# No passwords, no sessions, no JWT. Just cryptographic proof.
#
# FOAF uses the eth gem for secp256k1 operations (Ruby 3.2).
# Consuming apps on older Ruby can use OpenSSL directly.
# Both produce compatible signatures.

class SignatureVerifier
  # Verify that a payload was signed by the holder of the given public key.
  #
  # @param payload [String] the signed data
  # @param signature [String] hex-encoded signature
  # @param public_key_hex [String] hex-encoded secp256k1 public key
  # @return [Boolean] true if signature is valid
  def self.verify(payload:, signature:, public_key_hex:)
    return false if signature.blank? || public_key_hex.blank?

    # Recover the public key from the signature and check it matches
    recovered = Eth::Signature.personal_recover(payload, signature)
    recovered.downcase == public_key_hex.downcase
  rescue StandardError => e
    Rails.logger.debug("[SignatureVerifier] Verification failed: #{e.message}")
    false
  end

  # Verify that a signature was produced by the holder of the given address.
  # Recovers the public key from the signature, derives the address, compares.
  # No database lookup — just math. Same as how blockchain nodes verify.
  #
  # @param payload [String] the signed data
  # @param signature [String] hex-encoded signature
  # @param address [String] 0x-prefixed address of the claimed signer
  # @return [Boolean]
  def self.verify_by_address(payload:, signature:, address:)
    return false if signature.blank? || address.blank?

    recovered_pub = Eth::Signature.personal_recover(payload, signature)
    recovered_address = Eth::Util.public_key_to_address(Eth::Util.hex_to_bin(recovered_pub)).to_s
    recovered_address.downcase == address.downcase
  rescue StandardError => e
    Rails.logger.debug("[SignatureVerifier] Address verification failed: #{e.message}")
    false
  end

  # Generate a new secp256k1 keypair.
  #
  # @return [Hash] { address:, public_key:, private_key: }
  def self.generate_keypair
    key = Eth::Key.new
    {
      address: key.address.to_s.downcase,
      public_key: key.public_hex,
      private_key: key.private_hex
    }
  end

  # Sign a payload with a private key. For testing.
  #
  # @param payload [String] data to sign
  # @param private_key [String] hex-encoded private key
  # @return [String] hex-encoded signature
  def self.sign(payload:, private_key:)
    key = Eth::Key.new(priv: private_key)
    key.personal_sign(payload)
  end
end
