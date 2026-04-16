# frozen_string_literal: true

module Api
  module V1
    class TransfersController < ApiController
      # GET /api/v1/transfers?transactionHash=...
      # In FOAF, "transactionHash" maps to operation ID.
      def show
        op = Operation.find_by!(id: params[:transactionHash])
        events = TrustlineEvent.where(operation: op, event_type: "Transfer")

        render json: events.map { |e|
          {
            currencyNetwork: e.currency_network.address,
            path: e.path,
            value: e.value&.to_f,
            feePayer: e.fee_payer,
            totalFees: e.total_fees&.to_f,
            feesPaid: e.fees_paid,
            extraData: e.extra_data
          }
        }
      end
    end
  end
end
