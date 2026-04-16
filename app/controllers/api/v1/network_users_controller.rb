# frozen_string_literal: true

module Api
  module V1
    class NetworkUsersController < ApiController
      before_action :find_network!

      # GET /api/v1/networks/:network_address/users/:address
      def show
        address = params[:address]
        summary = NetworkService.user_summary(@network, address)
        render json: summary.transform_values(&:to_f)
      end

      # GET /api/v1/networks/:network_address/users/:address/trustlines
      def trustlines
        address = params[:address]
        tls = Foaf::TrustlineRecord.in_network(@network.id).for_address(address)
        render json: tls.map { |tl| TrustlineService.serialize(tl, from_address: address) }
      end

      # GET /api/v1/networks/:network_address/users/:address/events
      def events
        address = params[:address]
        scope = TrustlineEvent.in_network(@network.id).for_address(address)
        scope = scope.of_type(params[:type]) if params[:type].present?
        scope = scope.where("trustline_events.created_at >= ?", Time.at(params[:fromBlock].to_i)) if params[:fromBlock].present?
        render json: scope.recent.limit(100).map { |e| serialize_event(e, address) }
      end

      private

      def find_network!
        @network = CurrencyNetwork.find_by!(address: params[:network_address])
      end

      def serialize_event(event, user_address)
        direction = if event.from_address == user_address
          "sent"
        elsif event.to_address == user_address
          "received"
        end

        {
          networkAddress: event.currency_network.address,
          blockNumber: event.id,  # sequential ID as block number equivalent
          timestamp: event.created_at.to_i,
          type: event.event_type,
          from: event.from_address,
          to: event.to_address,
          direction: direction,
          counterParty: direction == "sent" ? event.to_address : event.from_address,
          user: user_address,
          transactionId: event.operation_id,
          # Event-type specific fields
          value: event.value&.to_f,
          extraData: event.extra_data,
          creditlineGiven: event.creditline_given&.to_f,
          creditlineReceived: event.creditline_received&.to_f,
          interestRateGiven: event.interest_rate_given,
          interestRateReceived: event.interest_rate_received,
          isFrozen: event.is_frozen,
          balance: event.balance&.to_f,
          path: event.path,
          feePayer: event.fee_payer,
          totalFees: event.total_fees&.to_f,
          feesPaid: event.fees_paid
        }.compact
      end
    end
  end
end
