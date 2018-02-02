module ActiveRecord
  class Base
    include Vmdb::Logging

    # Truncates the table.
    #
    # ==== Example
    #
    #   Post.truncate
    def self.truncate
      connection.truncate(table_name, "#{name} Truncate")
    end

    def self.reindex
      _log.info("Reindexing table #{reindex_table_name}")
      connection.reindex_table(reindex_table_name)
      _log.info("Reindexing table #{reindex_table_name}")
    end

    def self.reindex_table_name
      table_name
    end
  end
end
