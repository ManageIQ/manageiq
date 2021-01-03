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

      def delete_sessions(session_ids)
        session_ids.each { |session_id| GLOBAL_HASH_TABLE.delete(session_id) }
      end

      private

      def find_session(_req, session_id)
        session_id ||= generate_sid
        session = GLOBAL_HASH_TABLE[session_id] || {}
        [session_id, session]
      end

      def write_session(_req, session_id, session_data, _options = nil)
        GLOBAL_HASH_TABLE[session_id] = session_data
        session_id
      end

      def delete_session(_req, session_id, _options)
        GLOBAL_HASH_TABLE.delete(session_id)
        generate_sid
      end
    end
  end
end

module ManageIQ
  module Session
    class MemoryStoreAdapter < AbstractStoreAdapter
      def type
        :memory_store
      end
    end
  end
end
