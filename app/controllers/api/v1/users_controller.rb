# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApiController
      # GET /api/v1/users/:address/trustlines
      # All trustlines across all networks for a user.
      def trustlines
        address = params[:address]
        tls = Foaf::TrustlineRecord.for_address(address).includes(:currency_network)
        render json: tls.map { |tl| TrustlineService.serialize(tl, from_address: address) }
      end

      # GET /api/v1/users/:address/events
      def events
        address = params[:address]
        scope = TrustlineEvent.for_address(address)
        scope = scope.of_type(params[:type]) if params[:type].present?
        scope = scope.where("trustline_events.created_at >= ?", Time.at(params[:fromBlock].to_i)) if params[:fromBlock].present?
        render json: scope.recent.limit(100).map { |e| serialize_event(e, address) }
      end

      private

      def serialize_event(event, user_address)
        direction = event.from_address == user_address ? "sent" : "received"

        {
          networkAddress: event.currency_network.address,
          blockNumber: event.id,
          timestamp: event.created_at.to_i,
          type: event.event_type,
          from: event.from_address,
          to: event.to_address,
          direction: direction,
          counterParty: direction == "sent" ? event.to_address : event.from_address,
          user: user_address,
          transactionId: event.operation_id,
          value: event.value&.to_f,
          extraData: event.extra_data
        }.compact
      end
    end
  end
end
