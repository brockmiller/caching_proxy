require_relative 'caching_proxy/resolvers/multiple_destination_resolver'
require_relative 'caching_proxy/resolvers/single_destination_resolver'
require_relative 'caching_proxy/server'
require_relative 'caching_proxy/simple_lru_cache'
require_relative 'caching_proxy/version'

module CachingProxy
  class << self
    attr_accessor :logger

    def logger=(logger)
      @logger = logger
    end
  end
end
