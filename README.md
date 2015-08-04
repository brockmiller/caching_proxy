# Caching Proxy
A lightweight HTTP reverse proxy cache built in Ruby.

Built and tested using Ruby version `2.0.0-p247`.

## Install and Run

Clone the repo and then cd into `caching_proxy`:

    $ git clone git@github.com:brockmiller/caching_proxy.git
    $ cd caching_proxy

Then, install the dependencies:

    $ bundle install --path vendor/bundle

The following rake tasks are available to start the proxy service:

    bundle exec rake proxy:multiple[port]                                  # Run the server to proxy for multiple destinations
    bundle exec rake proxy:single[port,destination_host,destination_port]  # Run the server to proxy for a single destination

Before running the proxy, be sure to verify the configuration for cache options and destinations (multiple destination mode only). See sections below on [Configuring the Destinations](#configuring-the-destinations) and [Configuring the Cache](#configuring-the-cache).

To run the proxy in single destination mode on port 9000 and proxy for http://example.com:8080, you would run:

    $ bundle exec rake proxy:single[9000,http://example.com,8080]

To run the proxy in multiple destination mode (with configuration in `resources/destinations.yml`) on port 9000, you would run:

    $ bundle exec rake proxy:multiple[9000]

Once your proxy server is running, you can send it requests using `curl` or any other HTTP tool:

Example command using the default configuration in multiple destination mode:

    $ curl -XGET http://localhost:9000/github/github

## Proxying
`caching_proxy` acts as a transparent reverse HTTP proxy that will proxy for one or more destination hosts and cache GET requests, improving server performance and reducing overall workload on your destination servers. A destination host can be any HTTP server and is defined by its server address and port. Request URIs are passed directly through the proxy and on to the destination, preserving the intention of the request.

The proxy currently supports two strategies for specifying destinations.

### Single Destination Proxy
This is the most basic configuration, allowing for one destination. The proxy will only forward requests on to this host.

This mode takes a single host address and port for configuration.

### Multiple Destination Proxy
A slightly different strategy is used to support proxying for multiple destinations. In this configuration, you can specify one or more destination hosts by giving each destination a unique alias which is used for routing the requests. The alias should then be included in the first part of the request URI to indicate which destination the request should be routed to.

For example, this can be very useful if you want to proxy for a set of API services and route all of your requests through a single host (the proxy) and not have to direct each API request to its specific service host address. Think of it as a poor man's DNS resolution for API services which also caches GET results.

Let's say I have two API services that I'd like to proxy for: `customer-service` and `account-service` (fictional services). After configuring these two destinations in my `destinations.yml` config file, I can then issue the following requests to get data from my services through the proxy.

Get details for customer with ID 17 via the customer-service:

    GET http://localhost:9000/customer-service/customers/17/

Get account info for the same customer:

    GET http://localhost:9000/account-service/accounts/?customer_id=17

#### Configuring the Destinations
Destinations should be configured in `resources/destinations.yml` and follow a simlpe pattern:

    :{destination-alias}:
      :host: {destination host address}
      :port: {destination host port}

An example configuration which proxies for two destinations, github and rubygems:

    :github:
      :host: https://github.com
      :port: 443
    :rubygems:
      :host: https://rubygems.org
      :port: 443

## Caching
Caching occurs automatically for all GET requests according to the rules configured. Cache entries are stored in-memory, providing very fast lookup times.

Caching options include:  time to live (TTL) of each cache entry, maximum byte size of the total cache, and maximum number of cache entries. Old cache entries are pruned according to least recently used (LRU) rules, meaning entries with the longest duration since last being accessed are evicted first.

### Configuring the Cache
The cache configuration lives in `resources/cache.yml` and expects the following fields:

    :ttl - Time to live (duration) of each entry, in milliseconds
    :max_size_bytes - Maximum size of the cache, in bytes
    :max_size_elements - Maximum number of elements to store

## Testing
This project includes basic unit test coverage in `rspec`, which lives in the `spec` directory. There are currently no integration tests.

To run all `rspec` tests:

    $ bundle exec rspec spec/
