# frozen_string_literal: true

module Api
  module V1
    class MetaController < ApiController
      def version
        render json: "foaf/v0.1.0"
      end
    end
  end
end
