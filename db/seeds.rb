# Phase 1 protocol parameters — all fees zero, defaults established.

ProtocolParameter.find_or_create_by!(key: "transaction_fee_bps") do |p|
  p.value = "0"
  p.description = "Transaction fee in basis points (0 = disabled)"
end

ProtocolParameter.find_or_create_by!(key: "markup_fee_bps") do |p|
  p.value = "0"
  p.description = "Markup fee in basis points (0 = disabled)"
end

ProtocolParameter.find_or_create_by!(key: "routing_premium_bps") do |p|
  p.value = "0"
  p.description = "Routing premium in basis points (0 = disabled)"
end

ProtocolParameter.find_or_create_by!(key: "max_hops_default") do |p|
  p.value = "5"
  p.description = "Default maximum hops for multi-hop transfers"
end

ProtocolParameter.find_or_create_by!(key: "fee_distribution_node_pct") do |p|
  p.value = "50"
  p.description = "Fee distribution: node operators percentage"
end

ProtocolParameter.find_or_create_by!(key: "fee_distribution_treasury_pct") do |p|
  p.value = "30"
  p.description = "Fee distribution: treasury percentage"
end

ProtocolParameter.find_or_create_by!(key: "fee_distribution_burn_pct") do |p|
  p.value = "20"
  p.description = "Fee distribution: burn percentage"
end

puts "Protocol parameters seeded (Phase 1: all fees zero)"
