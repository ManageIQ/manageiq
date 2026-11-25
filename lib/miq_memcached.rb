require 'linux_admin'

module MiqMemcached
  def self.server_address
    ENV["MEMCACHED_SERVER"] || ::Settings.session.memcache_server
  end

  def self.default_client_options
    options = {
      # The default consecutive socket_max_failures is 2. Since we don't have a failover
      # memcached to use when one is down, we need to try harder to allow this client to
      # retry memcached before marking it failed.
      #
      # The client options are described here:
      # https://github.com/petergoldstein/dalli/wiki/Dalli::Client-Options
      :socket_max_failures => 5,
      # Direct Dalli Clients won't use connection pool but will be threadsafe.
      # ActiveSupport::Cache::MemCacheStore and ManageIQ::Session::MemCacheStoreAdapter
      # use threadsafe but also accept connection pool options.
      :threadsafe => true
    }

    if ENV["MEMCACHED_ENABLE_SSL"]
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.ca_file = ENV["MEMCACHED_SSL_CA"] if ENV["MEMCACHED_SSL_CA"]
      ssl_context.verify_hostname = true
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
      options[:ssl_context] = ssl_context
    end

    options
  end

  # @param options options passed to the memcached client
  # e.g.: :namespace => namespace
  def self.client(options)
    require 'dalli'

    merged_options = default_client_options.merge(options)
    Dalli::Client.new(MiqMemcached.server_address, merged_options)
  end

  # Warn if any configured memcached server is older than the minimum version
  # supported by Dalli. Dalli only talks the memcached meta protocol, and
  # ActiveSupport::Cache::MemCacheStore swallows the resulting Dalli errors, so
  # an unsupported server otherwise fails silently.
  #
  # This never raises. Servers that cannot be reached are skipped.
  #
  # @return [Boolean] false if an unsupported version was found, true otherwise
  def self.verify_version
    require 'dalli'

    minimum   = Gem::Version.new(Dalli::MIN_SUPPORTED_MEMCACHED_VERSION)
    memcached = client({})

    memcached.version.map do |server, version|
      next true if version.nil? || Gem::Version.new(version) >= minimum

      $log.warn("memcached server #{server} is version #{version}, but Dalli #{Dalli::VERSION} requires #{minimum} or later. Caching and token storage may fail silently.")
      false
    end.all?
  rescue StandardError => err
    $log.warn("Unable to verify memcached version: #{err.class}: #{err.message}")
    true
  ensure
    memcached&.close
  end
end
