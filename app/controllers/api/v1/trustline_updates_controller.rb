# frozen_string_literal: true

module Api
  module V1
    class TrustlineUpdatesController < ApiController
      # POST /api/v1/networks/:network_address/trustlines/update
      def create
        network = CurrencyNetwork.find_by!(address: params[:network_address])

        result = TrustlineService.update_trustline(
          network: network,
          creditor_address: params[:creditor_address],
          debtor_address: params[:debtor_address],
          creditline_given: BigDecimal(params[:creditline_given].to_s),
          creditline_received: BigDecimal(params[:creditline_received].to_s)
        )

        render json: {
          action: result[:action],
          trustline: TrustlineService.serialize(result[:trustline], from_address: params[:creditor_address])
        }, status: :created
      end

      # DELETE /api/v1/networks/:network_address/trustlines/update/:counter_party_address
      def cancel
        network = CurrencyNetwork.find_by!(address: params[:network_address])

        result = TrustlineService.cancel_update(
          network: network,
          initiator_address: params[:initiator_address],
          counterparty_address: params[:counter_party_address]
        )

        render json: { action: result[:action] }
      end
    end
  end
end
