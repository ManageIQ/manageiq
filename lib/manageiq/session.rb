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

    # Fetch the currently configured session store
    #
    # This is lazily fetched and memoized from Rails' middleware stack, as we
    # don't want to fetch/precache it from Rails until that process of defining
    # the middleware stack has completed.
    def self.store
      @store ||= fetch_store_from_rails
    end

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

      @store = nil
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

    # :call-seq:
    #   ManageIQ::Session.revoke(id)         -> Array
    #   ManageIQ::Session.revoke(id1, id2)   -> Array
    #   ManageIQ::Session.revoke([id1, id2]) -> Array
    #
    # Revokes sessions for one or multiple session ids given.  Returns the list
    # of session ids provided and sent to be delete from the session @store.
    #
    def self.revoke(*session_ids)
      store.delete_sessions(session_ids.flatten)
    end

    # Create a fake request that can be passed to methods in the SessionStore
    # (like `.delete_session`) where a request object is required.
    #
    # Create a new one each time instead of memoizing to avoid data getting
    # attached to the request hash (env).
    def self.fake_request
      FakeRequest.new({})
    end

    # :nodoc:
    #
    # Loops through the middleware stack and finds the configured session store
    # for the Rails application.
    #
    # Currently there is "good" no way to fetch the given instance of the
    # session store, so this is the best option available.
    #
    def self.fetch_store_from_rails
      middleware          = Rails.application
      session_store_klass = ActionDispatch::Session::SessionObject

      loop do
        return nil        if middleware.nil?
        return middleware if middleware.kind_of?(session_store_klass)

        middleware = middleware.instance_variable_get(:@app)
      end
    end
    private_class_method :fetch_store_from_rails
  end
end
