# frozen_string_literal: true

# BIP-39 compatible seed phrase generation and key derivation.
# Generates 12-word mnemonic → derives secp256k1 private key deterministically.
# Same standard as Bitcoin/Ethereum wallets — any BIP-39 compatible wallet
# can recover the key from the seed phrase.

require "openssl"
require "securerandom"

class SeedPhrase
  # BIP-39 English word list (2048 words).
  # Loaded once at boot from the standard list.
  WORDLIST = File.readlines(
    File.join(__dir__, "bip39_english.txt"), chomp: true
  ).freeze

  # Generate a 12-word seed phrase and derive a keypair from it.
  #
  # @return [Hash] { seed_phrase:, address:, public_key:, private_key: }
  def self.generate
    mnemonic = generate_mnemonic
    keypair = derive_keypair(mnemonic)
    { seed_phrase: mnemonic, **keypair }
  end

  # Recover a keypair from an existing seed phrase.
  #
  # @param mnemonic [String] 12-word seed phrase
  # @return [Hash] { address:, public_key:, private_key: }
  def self.recover(mnemonic)
    words = mnemonic.strip.downcase.split(/\s+/)
    raise ArgumentError, "Seed phrase must be 12 words" unless words.size == 12
    raise ArgumentError, "Invalid word in seed phrase" unless words.all? { |w| WORDLIST.include?(w) }

    derive_keypair(mnemonic)
  end

  private

  # Generate a random 12-word BIP-39 mnemonic.
  # 128 bits of entropy → 4 bit checksum → 132 bits → 12 × 11-bit indices.
  def self.generate_mnemonic
    entropy = SecureRandom.random_bytes(16) # 128 bits
    checksum = Digest::SHA256.digest(entropy)

    # Append first 4 bits of checksum to entropy
    bits = entropy.unpack1("B*") + checksum.unpack1("B4")

    # Split into 12 groups of 11 bits, map to words
    words = bits.scan(/.{11}/).map { |b| WORDLIST[b.to_i(2)] }
    words.join(" ")
  end

  # Derive a secp256k1 keypair from a mnemonic using BIP-39 seed derivation.
  # mnemonic → PBKDF2(mnemonic, "mnemonic" + passphrase) → 512-bit seed → first 256 bits as private key
  def self.derive_keypair(mnemonic)
    # BIP-39: PBKDF2-HMAC-SHA512, 2048 iterations, salt = "mnemonic" (no passphrase)
    seed = OpenSSL::KDF.pbkdf2_hmac(
      mnemonic.encode("UTF-8"),
      salt: "mnemonic",
      iterations: 2048,
      length: 64,
      hash: "SHA512"
    )

    # Use first 32 bytes as private key
    private_hex = seed[0..31].unpack1("H*")

    # Generate the full keypair via eth gem
    key = Eth::Key.new(priv: private_hex)
    {
      address: key.address.to_s.downcase,
      public_key: key.public_hex,
      private_key: key.private_hex
    }
  end
end
