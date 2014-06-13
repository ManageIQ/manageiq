# Be sure to restart your server when you modify this file.
# Port of old CGI::Session::MemoryStore to Rails 3
module ActionDispatch
  module Session
    # In-memory session storage class.
    #
    # Implements session storage as a global in-memory hash.  Session
    # data will only persist for as long as the ruby interpreter
    # instance does.
    class MemoryStore < AbstractStore
      GLOBAL_HASH_TABLE = {} #:nodoc:

      private
      def get_session(env, session_id)
        session_id ||= generate_sid
        session = GLOBAL_HASH_TABLE[session_id] || {}
        session = Rack::Session::Abstract::SessionHash.new(self, env).merge(session)
        [session_id, session]
      end

      def set_session(env, session_id, session_data, options = nil)
        GLOBAL_HASH_TABLE[session_id] = session_data
        session_id
      end

      def destroy_session(env, session_id, options)
        GLOBAL_HASH_TABLE.delete(session_id)
        generate_sid
      end
    end
  end
end
