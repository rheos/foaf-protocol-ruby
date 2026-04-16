# frozen_string_literal: true

module Api
  module V1
    class NetworksController < ApiController
      before_action :find_network!, only: [:show, :users, :trustlines]

      # GET /api/v1/networks
      def index
        networks = CurrencyNetwork.all
        render json: networks.map { |n| serialize_network(n) }
      end

      # GET /api/v1/networks/:address
      def show
        render json: serialize_network(@network)
      end

      # GET /api/v1/networks/:address/users
      def users
        render json: NetworkService.users(@network)
      end

      # GET /api/v1/networks/:address/trustlines
      def trustlines
        tls = Foaf::TrustlineRecord.in_network(@network.id)
        render json: tls.map { |tl| TrustlineService.serialize(tl) }
      end

      private

      def serialize_network(network)
        {
          address: network.address,
          name: network.name,
          abbreviation: network.symbol,
          decimals: network.decimals,
          numUsers: NetworkService.users(network).size,
          capacityImbalanceFeeDivisor: network.capacity_imbalance_fee_divisor,
          defaultInterestRate: network.default_interest_rate,
          interestRateDecimals: 2,
          customInterests: network.custom_interests,
          preventMediatorInterests: network.prevent_mediator_interests,
          isFrozen: network.is_frozen
        }
      end
    end
  end
end
