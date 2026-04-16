# frozen_string_literal: true

module Api
  module V1
    class MetaController < ApiController
      def version
        render json: "foaf/v0.1.0"
      end

      # POST /api/v1/keypair
      # Generate a new secp256k1 keypair with BIP-39 seed phrase.
      # Returns everything once. FOAF stores nothing.
      # The consuming app stores what it needs. The user writes down the seed phrase.
      def keypair
        result = SeedPhrase.generate
        render json: {
          seedPhrase: result[:seed_phrase],
          address: result[:address],
          publicKey: result[:public_key],
          privateKey: result[:private_key]
        }
      end

      # POST /api/v1/recover
      # Recover a keypair from a seed phrase. FOAF stores nothing.
      def recover
        result = SeedPhrase.recover(params[:seed_phrase])
        render json: {
          address: result[:address],
          publicKey: result[:public_key],
          privateKey: result[:private_key]
        }
      rescue ArgumentError => e
        render json: { error: e.message }, status: :bad_request
      end
    end
  end
end
