require "extensions/session_extension"

##
#
# Wrapper class around the session/store/configuration, as well custom
# additions to the Rails/Rake session storage to allow interacting with it from
# the backend without a request object required.
#
module ManageIQ
  module Session
    FakeRequest = Struct.new(:env)

    # :call-seq:
    #   ManageIQ::Session.store=(Symbol)
    #
    # Set the session store for a given SessionStore adapter.
    #
    # Valid session stores for ManageIQ:
    #
    # - :active_record_store
    # - :memory_store
    # - :mem_cache_store
    #
    def self.store=(session_store)
      adapter_klass = "ManageIQ::Session::#{session_store.to_s.camelize}Adapter".safe_constantize
      raise ArgumentError, "invalid session store adapter: #{session_store.inspect}" unless adapter_klass

      configure_session_store(adapter_klass.new)
    end

    # :nodoc:
    #
    # Configures the session store to be used by the Rails application
    # (Vmdb::Application) and logs what is being used.
    def self.configure_session_store(adapter)
      Vmdb::Application.config.session_store(*adapter.session_store_config_args)
      msg = "Using session_store: #{Vmdb::Application.config.session_store}"
      _log.info(msg)
      puts "** #{msg}" if !Rails.env.production? && adapter.type != :mem_cache_store
    end

    # Create a fake request that can be passed to methods in the SessionStore
    # (like `.delete_session`) where a request object is required.
    #
    # Create a new one each time instead of memoizing to avoid data getting
    # attached to the request hash (env).
    def self.fake_request
      FakeRequest.new({})
    end
  end
end
