# FOAF protocol API is open for reads (like a public blockchain).
# Writes require signature verification, not CORS restrictions.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
