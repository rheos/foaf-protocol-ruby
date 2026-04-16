# frozen_string_literal: true

require "bigdecimal"

require_relative "protocol/balance_math"
require_relative "protocol/fee_calculator"
require_relative "protocol/trustline_state_machine"
require_relative "protocol/multi_hop_executor"
require_relative "protocol/credloop_detector"

module Foaf
  module Trustline
    # Pure protocol logic — no Rails, no I/O, no database.
    # This entire module is the future Rust extraction boundary.
    module Protocol
    end
  end
end
