# Allow connections from Docker containers and localhost
Rails.application.config.hosts << "host.docker.internal"
Rails.application.config.hosts << "foaf"
Rails.application.config.hosts << "localhost"
