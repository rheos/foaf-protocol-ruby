# frozen_string_literal: true

module Api
  module V1
    class MetaController < ApiController
      def version
        render json: "foaf/v0.1.0"
      end

      # POST /api/v1/keypair
      # Generate a new secp256k1 keypair. Returns everything once.
      # FOAF stores nothing — the consuming app is responsible for the keys.
      # Like a wallet generating a seed phrase: shown once, never stored here.
      def keypair
        kp = SignatureVerifier.generate_keypair
        render json: {
          address: kp[:address],
          publicKey: kp[:public_key],
          privateKey: kp[:private_key]
        }
      end
    end
  end
end
