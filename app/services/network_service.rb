# frozen_string_literal: true

# Currency network lifecycle.
# A network is like a Scrypto component instance — deployed once,
# then trustlines and transfers happen within it.

class NetworkService
  # Deploy a new currency network.
  # Mirrors CurrencyNetworkBasic.init()
  #
  # @param name [String]
  # @param symbol [String]
  # @param decimals [Integer]
  # @param owner_address [String] identity that creates/owns the network
  # @param capacity_imbalance_fee_divisor [Integer] 0 = no fees
  # @param max_hops [Integer]
  # @return [CurrencyNetwork]
  def self.deploy(name:, symbol:, decimals: 2, owner_address:,
                  capacity_imbalance_fee_divisor: 0,
                  default_interest_rate: 0,
                  custom_interests: false,
                  prevent_mediator_interests: false,
                  max_hops: 5)
    # Generate a deterministic address for the network (like a contract deployment)
    address = generate_network_address(name, symbol, owner_address)

    network = CurrencyNetwork.create!(
      address: address,
      name: name,
      symbol: symbol,
      decimals: decimals,
      capacity_imbalance_fee_divisor: capacity_imbalance_fee_divisor,
      default_interest_rate: default_interest_rate,
      custom_interests: custom_interests,
      prevent_mediator_interests: prevent_mediator_interests,
      max_hops: max_hops,
      owner_address: owner_address
    )

    # Record the deployment as an operation
    Operation.create!(
      operation_type: "deploy_network",
      module_name: "trustline",
      currency_network: network,
      actor_address: owner_address,
      inputs: {
        name: name,
        symbol: symbol,
        decimals: decimals,
        capacity_imbalance_fee_divisor: capacity_imbalance_fee_divisor,
        max_hops: max_hops
      },
      status: "applied"
    )

    network
  end

  # List all users (addresses) that have at least one trustline in a network.
  def self.users(network)
    addresses_a = Foaf::TrustlineRecord.in_network(network.id).pluck(:user_a_address)
    addresses_b = Foaf::TrustlineRecord.in_network(network.id).pluck(:user_b_address)
    (addresses_a + addresses_b).uniq.sort
  end

  # Get aggregated account summary for a user in a network.
  # Mirrors Trustlines relay GET /networks/:addr/users/:addr
  def self.user_summary(network, address)
    trustlines = Foaf::TrustlineRecord.in_network(network.id).for_address(address)

    total_given = BigDecimal("0")
    total_received = BigDecimal("0")
    left_given = BigDecimal("0")
    left_received = BigDecimal("0")
    total_balance = BigDecimal("0")

    trustlines.each do |tl|
      user_is_a = tl.user_is_a?(address)
      balance = Foaf::Trustline::Protocol::BalanceMath.balance_for_user(
        balance: tl.balance, user_is_a: user_is_a
      )
      given = Foaf::Trustline::Protocol::BalanceMath.creditline_given_for_user(
        creditline_a_to_b: tl.creditline_given,
        creditline_b_to_a: tl.creditline_received,
        user_is_a: user_is_a
      )
      received = Foaf::Trustline::Protocol::BalanceMath.creditline_received_for_user(
        creditline_a_to_b: tl.creditline_given,
        creditline_b_to_a: tl.creditline_received,
        user_is_a: user_is_a
      )

      total_given += given
      total_received += received
      total_balance += balance

      # "left" = remaining capacity
      left_given += [given + balance, BigDecimal("0")].max
      left_received += Foaf::Trustline::Protocol::BalanceMath.capacity(
        balance: balance, creditline_received: received
      )
    end

    {
      given: total_given,
      received: total_received,
      left_given: left_given,
      left_received: left_received,
      balance: total_balance
    }
  end

  private

  def self.generate_network_address(name, symbol, owner_address)
    # Deterministic address from network params — like a CREATE2 deployment
    digest = Digest::SHA256.hexdigest("#{name}:#{symbol}:#{owner_address}:#{Time.current.to_f}")
    "0x#{digest[0..39]}"
  end
end
