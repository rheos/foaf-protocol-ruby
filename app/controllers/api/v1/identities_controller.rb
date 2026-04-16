# frozen_string_literal: true

module Api
  module V1
    class IdentitiesController < ApiController
      # POST /api/v1/identities
      def create
        identity = IdentityService.register(public_key: params[:public_key])

        render json: {
          identity: identity.address,
          publicKey: identity.public_key
        }, status: :created
      end

      # GET /api/v1/identities/:address
      def show
        identity = Identity.find_by!(address: params[:address])

        render json: {
          identity: identity.address,
          publicKey: identity.public_key
        }
      end
    end
  end
end
