require "extensions/active_record_session_store_patch"

module ManageIQ
  module Session
    class ActiveRecordStoreAdapter < AbstractStoreAdapter
      def type
        :active_record_store
      end
    end
  end
end
