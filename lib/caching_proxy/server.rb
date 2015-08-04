require 'webrick'

module CachingProxy
  class Server
    attr_reader :http_server, :cache, :destination_resolver

    # Creates a new CachingProxy::Server instance to reverse proxy for and cache GET requests to one or more
    # destination servers.
    #
    # @param port [Fixnum] the port to listen on
    # @param cache [Cache] the cache store
    # @param destination_resolver [DestinationResolver] the resolver for routing to hosts
    #
    def initialize(port, cache, destination_resolver)
      fail ArgumentError.new('You must supply a valid cache to use.') if cache.nil?
      @cache = cache

      fail ArgumentError.new('You must supply a valid destination resolver to use.') if destination_resolver.nil?
      @destination_resolver = destination_resolver

      @http_server = WEBrick::HTTPServer.new(Port: port)
      @http_server.mount_proc('/') { |request, response| do_request(request, response) }
    end

    # Start the server and listen for requests until a trap is signaled.
    def run
      trap('INT') { http_server.shutdown }
      http_server.start
    end

    # Process a Request and send back a Response. The response is sent back by modifying
    # the given response parameter (due to WEBrick's implementation...)
    def do_request(request, response)
      if request.request_method != 'GET'
        response.status = 405
        LOG.error "Unsupported request method #{request.request_method}"
        return
      end

      do_get(request, response)
    end

    # Handle a GET request, returning a cached result if one exists and otherwise
    # forwarding it on to a destination host.
    def do_get(request, response)
      request_path = request.unparsed_uri
      page_response = cache.get(request_path)

      if page_response.nil?
        destination = destination_resolver.get_destination_for_path(request_path)
        LOG.info "cache miss, forwarding the request on to:  #{destination}"

        page_response = forward_request(destination)
        cache.put(request_path, page_response)
      end

      response.status, response.body = page_response
    end

    def forward_request(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https')) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request)
      end

      [response.code, response.body]
    end
    private :forward_request
  end
end
