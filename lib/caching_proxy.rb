require 'logger'

module CachingProxy
  LOG = Logger.new(STDOUT)
end

require_relative 'caching_proxy/resolvers/multiple_destination_resolver'
require_relative 'caching_proxy/resolvers/single_destination_resolver'
require_relative 'caching_proxy/server'
require_relative 'caching_proxy/cache'
require_relative 'caching_proxy/version'
