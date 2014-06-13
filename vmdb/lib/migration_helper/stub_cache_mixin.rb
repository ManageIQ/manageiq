module MigrationHelper
  module StubCacheMixin
    private

    def clear_caches
      connection.schema_cache.clear!
      reset_column_information
    end

    def clearing_caches
      clear_caches
      yield
    ensure
      clear_caches
    end
  end
end
