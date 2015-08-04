require 'yaml'

module CachingProxy::Resolvers

  # Destination resolver for specifying multiple destination hosts. This resolver uses
  # the first part of the URL path for routing to the destination host.
  class MultipleDestinationResolver
    attr_reader :destination_map

    # Initialize from a YAML file
    def self.from_yaml(yaml_file)
      new(YAML.load_file(yaml_file))
    end

    # Create a new destination resolver using the destination map for routing
    #
    # @param destination_map [Hash] a map of destination alias to host and port
    def initialize(destination_map)
      @destination_map = destination_map
    end

    # Get the final destination address according to the configured destinations and
    # the provided path
    #
    # @param path [String] the path to resolve
    # @return [URI] the destination address
    def get_destination_for_path(path)
      route, resource_path = extract_path_info(path)
      destination_info = destination_map[route.to_sym]
      fail DestinationNotFound.new(route) if destination_info.nil?

      URI.join("#{destination_info[:host]}:#{destination_info[:port]}", resource_path.to_s)
    end

    def extract_path_info(path)
      match_data = /\/([^\/]+)(\S+)*/.match(path)
      fail InvalidDestinationPath.new(path) if match_data.nil?

      match_data.captures
    end
  end

  class DestinationNotFound < StandardError
    def initialize(destination)
      msg = "No destination host configured for #{destination}"
      super(msg)
    end
  end

  class InvalidDestinationPath < StandardError
    def initialize(path)
      msg = "Invalid destination specified by path #{path}"
      super(msg)
    end
  end
end
