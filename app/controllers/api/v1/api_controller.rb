# frozen_string_literal: true

module Api
  module V1
    class ApiController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
      rescue_from RuntimeError, with: :bad_request
      rescue_from Foaf::Trustline::Protocol::InsufficientCapacity, with: :insufficient_capacity
      rescue_from Foaf::Trustline::Protocol::MaxFeeExceeded, with: :max_fee_exceeded

      private

      # Verify the request is signed by the claimed actor.
      # Like blockchain nodes verifying transaction signatures.
      def verify_signature!(address)
        payload = request.raw_post
        signature = request.headers["X-Signature"]

        unless signature.present?
          render json: { error: "Missing X-Signature header" }, status: :unauthorized
          return false
        end

        unless SignatureVerifier.verify(payload: payload, signature: signature, address: address)
          render json: { error: "Invalid signature for address #{address}" }, status: :unauthorized
          return false
        end

        true
      end

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable(exception)
        render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def insufficient_capacity(exception)
        render json: {
          error: exception.message,
          requested: exception.requested.to_f,
          available: exception.available.to_f
        }, status: :bad_request
      end

      def max_fee_exceeded(exception)
        render json: {
          error: exception.message,
          totalFees: exception.total_fees.to_f,
          maxFee: exception.max_fee.to_f
        }, status: :bad_request
      end

      def find_network!
        @network = CurrencyNetwork.find_by!(address: params[:network_address] || params[:address])
      end
    end
  end
end
