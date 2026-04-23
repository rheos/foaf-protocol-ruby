# frozen_string_literal: true

# Generic reads over protocol operations — the blockchain-RPC analog of
# eth_getLogs + eth_getTransactionReceipt. Consumers use these to build their
# own indexers. Nothing here is credloop-aware or analytics-aware.

module Api
  module V1
    class OperationsController < ApiController
      # GET /api/v1/networks/:address/operations
      #   ?limit=&since_id=&before_id=&type=&actor_address=
      def index
        find_network!

        limit = clamp_limit(params[:limit])
        scope = Operation.where(currency_network: @network)
        scope = scope.where(operation_type: params[:type]) if params[:type].present?
        scope = scope.where(actor_address: params[:actor_address]) if params[:actor_address].present?
        scope = scope.where("id > ?", params[:since_id].to_i) if params[:since_id].present?
        scope = scope.where("id < ?", params[:before_id].to_i) if params[:before_id].present?
        ops = scope.order(id: :desc).limit(limit)

        render json: { operations: ops.map { |op| serialize_op(op) } }
      end

      # GET /api/v1/operations/:id
      # Full operation detail, with all emitted events embedded.
      def show
        op = Operation.find(params[:id])
        events = TrustlineEvent.where(operation_id: op.id).order(:id)
        render json: serialize_op(op).merge(events: events.map { |e| serialize_event(e) })
      end

      private

      def clamp_limit(raw)
        n = raw.to_i
        return 20 if n <= 0
        return 200 if n > 200
        n
      end

      def serialize_op(op)
        {
          id: op.id,
          operation_type: op.operation_type,
          module_name: op.module_name,
          currency_network_address: op.currency_network.address,
          actor_address: op.actor_address,
          inputs: op.inputs,
          multi_hop_id: op.multi_hop_id,
          parent_operation_id: op.parent_operation_id,
          fee_amount: op.fee_amount.to_f,
          status: op.status,
          created_at: op.created_at.iso8601,
        }
      end

      def serialize_event(e)
        {
          id: e.id,
          event_type: e.event_type,
          from_address: e.from_address,
          to_address: e.to_address,
          value: e.value&.to_f,
          balance: e.balance&.to_f,
          extra_data: e.extra_data,
          creditline_given: e.creditline_given&.to_f,
          creditline_received: e.creditline_received&.to_f,
          path: e.path,
          fee_payer: e.fee_payer,
          total_fees: e.total_fees&.to_f,
          fees_paid: e.fees_paid,
          created_at: e.created_at.iso8601,
        }
      end
    end
  end
end
