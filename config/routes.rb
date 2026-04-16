Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # === NETWORKS ===
      resources :networks, param: :address, only: [:index, :show] do
        # Trustlines within a network
        member do
          get "users", to: "networks#users"
          get "trustlines", to: "networks#trustlines"
        end

        # User-scoped within a network
        resources :users, param: :address, only: [] do
          member do
            get "/", to: "network_users#show"
            get "trustlines", to: "network_users#trustlines"
            get "events", to: "network_users#events"
          end

          # Specific trustline between two users
          resources :trustlines, param: :counter_party_address, only: [:show] do
            member do
              get "events", to: "trustline_details#events"
            end
          end
        end

        # Pathfinding
        post "path-info", to: "pathfinding#path_info"
        post "max-capacity-path-info", to: "pathfinding#max_capacity_path_info"
        post "close-trustline-path-info", to: "pathfinding#close_trustline_path_info"
      end

      # === CROSS-NETWORK USER ENDPOINTS ===
      resources :users, param: :address, only: [] do
        member do
          get "trustlines", to: "users#trustlines"
          get "events", to: "users#events"
        end
      end

      # === KEYPAIR GENERATION ===
      post "keypair", to: "meta#keypair"

      # === TRANSFERS ===
      get "transfers", to: "transfers#show"   # ?transactionHash=...

      # === PENDING TRANSFERS (FOAF addition) ===
      resources :pending_transfers, only: [:index, :create] do
        member do
          put "confirm", to: "pending_transfers#confirm"
          put "reject", to: "pending_transfers#reject"
          delete "/", to: "pending_transfers#cancel"
        end
      end

      # === TRUSTLINE UPDATES ===
      post "networks/:network_address/trustlines/update",
           to: "trustline_updates#create", as: :trustline_update
      delete "networks/:network_address/trustlines/update/:counter_party_address",
             to: "trustline_updates#cancel", as: :cancel_trustline_update

      # === META ===
      get "version", to: "meta#version"
    end
  end
end
