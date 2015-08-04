# encoding: utf-8

require 'rubygems'
require_relative 'lib/caching_proxy'

begin
  require 'bundler'
rescue LoadError => e
  warn e.message
  warn "Run `gem install bundler` to install Bundler."
  exit -1
end

begin
  Bundler.setup(:development)
rescue Bundler::BundlerError => e
  warn e.message
  warn "Run `bundle install` to install missing gems."
  exit e.status_code
end

require 'rake'

require 'rubygems/tasks'
Gem::Tasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

task :test    => :spec
task :default => :spec

DESTINATION_FILE = '../resources/destinations.yml'
CACHE_FILE = '../resources/cache.yml'
namespace :proxy do
  desc 'Run the server to proxy for a single destination'
  task :single, [:port, :destination_host, :destination_port] do |t, args|
    port = args[:port]
    raise ArgumentError.new("proxy port is required") if port.nil?

    dest_host = args[:destination_host]
    dest_port = args[:destination_port]
    raise ArgumentError.new("destination host and port are both required") if dest_host.nil? || dest_port.nil?

    destination_resolver = CachingProxy::Resolvers::SingleDestinationResolver.new(dest_host, dest_port)

    cache_file = File.expand_path(CACHE_FILE, __FILE__)
    cache = CachingProxy::Cache.from_yaml(cache_file)

    server = CachingProxy::Server.new(port, cache, destination_resolver)
    server.run
  end

  desc 'Run the server to proxy for multiple destinations'
  task :multiple, [:port] do |t, args|
    port = args[:port]
    raise ArgumentError.new("proxy port is required") if port.nil?

    cache_file = File.expand_path(CACHE_FILE, __FILE__)
    cache = CachingProxy::Cache.from_yaml(cache_file)

    dest_file = File.expand_path(DESTINATION_FILE, __FILE__)
    destination_resolver = CachingProxy::Resolvers::MultipleDestinationResolver.from_yaml(dest_file)

    server = CachingProxy::Server.new(port, cache, destination_resolver)
    server.run
  end
end
