module CachingProxy::Resolvers

  # Simple proxy destination resolver for specifying a single destination host
  class SingleDestinationResolver
    attr_reader :base_uri

    def initialize(destination_address, destination_port)
      @base_uri = URI.parse("#{destination_address}:#{destination_port}")
    end

    def get_destination_for_path(path)
      URI.join(base_uri, path)
    end
  end
end
