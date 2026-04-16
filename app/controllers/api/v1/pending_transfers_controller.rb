# frozen_string_literal: true

module Api
  module V1
    class PendingTransfersController < ApiController
      # GET /api/v1/pending_transfers?address=...
      def index
        address = params[:address]
        incoming = PendingTransfer.incoming_for(address)
        outgoing = PendingTransfer.outgoing_for(address)

        render json: {
          incoming: incoming.map { |pt| serialize_pending(pt) },
          outgoing: outgoing.map { |pt| serialize_pending(pt) }
        }
      end

      # POST /api/v1/pending_transfers
      def create
        network = CurrencyNetwork.find_by!(address: params[:network_address])

        pt = PendingTransfer.create!(
          currency_network: network,
          from_address: params[:from_address],
          to_address: params[:to_address],
          value: BigDecimal(params[:value].to_s),
          max_fee: BigDecimal((params[:max_fee] || 0).to_s),
          fee_payer: params[:fee_payer] || "sender",
          path: params[:path],
          extra_data: params[:extra_data],
          status: "pending"
        )

        render json: serialize_pending(pt), status: :created
      end

      # PUT /api/v1/pending_transfers/:id/confirm
      def confirm
        pt = PendingTransfer.find(params[:id])
        raise "Transfer is not pending" unless pt.pending?

        # Execute the actual transfer
        result = TransferService.execute(
          network: pt.currency_network,
          sender_address: pt.from_address,
          receiver_address: pt.to_address,
          value: pt.value,
          max_fee: pt.max_fee,
          path: pt.path,
          fee_payer: pt.fee_payer,
          extra_data: pt.extra_data
        )

        pt.update!(
          status: "confirmed",
          confirmed_at: Time.current,
          resolved_at: Time.current
        )

        render json: {
          status: "confirmed",
          transfer: serialize_pending(pt),
          operation: result[:operation].id,
          totalFees: result[:total_fees].to_f
        }
      end

      # PUT /api/v1/pending_transfers/:id/reject
      def reject
        pt = PendingTransfer.find(params[:id])
        raise "Transfer is not pending" unless pt.pending?

        pt.update!(
          status: "rejected",
          rejected_reason: params[:reason],
          resolved_at: Time.current
        )

        render json: serialize_pending(pt)
      end

      # DELETE /api/v1/pending_transfers/:id
      def cancel
        pt = PendingTransfer.find(params[:id])
        raise "Transfer is not pending" unless pt.pending?

        pt.update!(
          status: "cancelled",
          resolved_at: Time.current
        )

        render json: serialize_pending(pt)
      end

      private

      def serialize_pending(pt)
        {
          id: pt.id,
          networkAddress: pt.currency_network.address,
          from: pt.from_address,
          to: pt.to_address,
          value: pt.value.to_f,
          maxFee: pt.max_fee.to_f,
          feePayer: pt.fee_payer,
          path: pt.path,
          extraData: pt.extra_data,
          status: pt.status,
          rejectedReason: pt.rejected_reason,
          confirmedAt: pt.confirmed_at&.iso8601,
          resolvedAt: pt.resolved_at&.iso8601,
          createdAt: pt.created_at.iso8601
        }
      end
    end
  end
end
