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
end
