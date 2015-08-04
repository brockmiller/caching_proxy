module CachingProxy

  # A simple cache store that uses in-memory storage and supports a configurable TTL, a max cache size in bytes, and
  # maximum number of entries. It uses the least recently used (LRU) strategy for pruning entries when making room
  # for new ones. It is currently not thread-safe.
  class Cache
    DEFAULT_OPTIONS = {
      ttl: 30 * 1000,
      max_size_bytes: 10 * 1024 * 1024,
      max_size_elements: 50
    }

    attr_reader :ttl, :max_size_bytes, :max_size_elements

    # Initialize from a YAML file
    def self.from_yaml(yaml_file)
      new(YAML.load_file(yaml_file))
    end

    # Create a new Cache instance with the given options
    #
    # @param options [Hash] an options Hash
    # @option options [Fixnum] :ttl expiration time (in msec) for individual entries
    # @option options [Fixnum] :max_size_bytes maximum size (in bytes) for the cache
    # @option options [Fixnum] :max_size_elements maximum number of elements in the cache
    def initialize(options={})
      options = DEFAULT_OPTIONS.merge(options)
      validate_options(options)

      @ttl = options[:ttl].to_i
      @max_size_bytes = options[:max_size_bytes].to_i
      @max_size_elements = options[:max_size_elements].to_i
      @current_size_bytes = 0
      LOG.info "initialized cache with ttl: #{@ttl}, max size: #{@max_size_bytes} bytes, #{@max_size_elements} elements"

      # Store cache values in memory using a Hash. In Ruby 1.9+, Hashes maintain the order that keys are inserted
      # in (similar to LinkedHashMap in Java), so this data structure provides both fast access to cache values
      # and the ability to maintain LRU ordering.
      @data = {}

      # Also utilize a Hash for mapping the cache key to its expiration time. The ordering of this Hash
      # will always be kept from oldest to newest and thus give us an efficient way to evict expired entries.
      @data_expires_at = {}
    end

    # Fetch the cache value for the given key, if one exists
    #
    # @param key [String] the key for the cache entry
    # @return [Object] the cached value
    # @return [nil] if no value is present
    def get(key)
      value = @data[key]

      if value
        if expired?(key)
          evict(key)
          return nil
        end

        touch(key)
        value = Marshal.load(value)
      end

      value
    end

    # Store the cache value at the given key.
    #
    # @param key [String] the key for the cache value
    # @param value [Object] the cache value
    # @return [Object] the cache value
    def put(key, value)
      cache_value = Marshal.dump(value)
      size = size_of(key, cache_value)

      # Don't write entries if they are too big
      if size > max_size_bytes
        LOG.error "cache entry for key #{key} of size #{size} would exceed the max size of #{max_size_bytes}"
        return nil
      end

      # Evict old entries
      evict(key) if @data.has_key?(key)
      evict_expired
      evict_lru_for_size(size)

      @data[key] = cache_value
      @data_expires_at[key] = Time.now.to_f + (ttl / 1000.0)
      @current_size_bytes += size

      value
    end

    private

    # Validate the cache options
    def validate_options(options)
      invalid_options = []
      options.each do |option, val|
        invalid_options << option unless val && val.to_i > 0
      end

      raise ArgumentError.new("#{invalid_options.join(', ')} cannot be nil and must be > 0") if invalid_options.any?
    end

    # Calculate the size required to store the given cache key and value.
    def size_of(key, cache_value)
      # Because this cache stores in-memory, we are technically approximating the
      # incremental memory footprint of this additional cache entry. This formula could
      # change, but I am using 2*keysize + valuesize + size_of_float
      cache_value.bytesize + 2 * key.bytesize + 8
    end

    # Calculate whether the given key is expired
    def expired?(key)
      @data_expires_at[key] < Time.now.to_f
    end

    # Touch the key so that it is at the end of the LRU list
    def touch(key)
      @data[key] = @data.delete(key)
    end

    # Evict the cache entry for key
    def evict(key)
      @data_expires_at.delete(key)
      cache_value = @data.delete(key)
      @current_size_bytes -= size_of(key, cache_value)
    end

    # Evict expired cache entries
    def evict_expired
      # Since data_expires_at keys are ordered by the age of the cache entry, we can bail out of the
      # loop as soon as we find the first unexpired key.
      @data_expires_at.each do |key, expiration|
        (expiration < Time.now.to_f) ? evict(key) : return
      end
    end

    # Evict the least recently used cache entries so that one element of size 'size' can be inserted.
    def evict_lru_for_size(size)
      evict(@data.keys.first) while (@data.length >= max_size_elements || @current_size_bytes + size > max_size_bytes)
    end
  end
end
