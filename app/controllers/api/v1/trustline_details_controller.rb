# frozen_string_literal: true

module Api
  module V1
    class TrustlineDetailsController < ApiController
      # GET /api/v1/networks/:network_address/users/:user_address/trustlines/:counter_party_address/events
      def events
        network = CurrencyNetwork.find_by!(address: params[:network_address])
        user = params[:user_address]
        counter_party = params[:counter_party_address]

        scope = TrustlineEvent.in_network(network.id)
          .where(
            "(from_address = ? AND to_address = ?) OR (from_address = ? AND to_address = ?)",
            user, counter_party, counter_party, user
          )
        scope = scope.of_type(params[:type]) if params[:type].present?

        render json: scope.recent.limit(100).map { |e|
          {
            networkAddress: network.address,
            blockNumber: e.id,
            timestamp: e.created_at.to_i,
            type: e.event_type,
            from: e.from_address,
            to: e.to_address,
            transactionId: e.operation_id,
            value: e.value&.to_f,
            extraData: e.extra_data,
            balance: e.balance&.to_f
          }.compact
        }
      end
    end
  end
end
