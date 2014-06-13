module VmdbDatabase::Logging
  extend ActiveSupport::Concern

  module ClassMethods
    def log_all_database_statistics
      log_database_statistics
      log_table_statistics
      log_table_size
      log_client_connections
    end

    def log_database_statistics
      $log.info("Current database bloat data\n#{connection.database_bloat.tableize(:leading_columns => ['table_name', 'index_name'])}")
    end

    def log_table_statistics
      $log.info("Current table statistics data\n#{connection.table_statistics.tableize(:leading_columns => ['table_name'])}")
    end

    def log_table_size
      $log.info("Current table size data\n#{connection.table_size.tableize(:leading_columns => ['table_name'])}")
    end

    def log_client_connections
      $log.info("Current client connections data\n#{connection.client_connections.tableize(:leading_columns => ['spid'], :trailing_columns => ['query'])}")
    end
  end
end
