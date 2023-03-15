# Be sure to restart your server when you modify this file.
module ActionDispatch
  module Session
    # In-memory session storage class.
    class MemoryStore < ActionDispatch::Session::CacheStore
      # typically points to the config.cache_store.
      # this points to a memory store instead
      def initialize(app, options)
        super(app, options.reverse_merge(:cache => ActiveSupport::Cache::MemoryStore.new))
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
