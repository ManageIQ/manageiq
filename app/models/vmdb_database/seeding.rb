module VmdbDatabase::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed
      db = seed_self
      db.seed
      db
    end

    def seed_self
      db = my_database || new

      db.name            = connection.current_database
      db.vendor          = connection.adapter_name
      db.version         = connection.database_version
      db.ipaddress       = db_server_ipaddress
      db.data_directory  = connection.data_directory            if connection.respond_to?(:data_directory)
      db.last_start_time = connection.last_start_time           if connection.respond_to?(:last_start_time)
      db.data_disk       = db_disk_size(db.data_directory) if EvmDatabase.local? && db.data_directory

      db.save!
      db
    end

    def db_server_ipaddress
      host = EvmDatabase.host
      if EvmDatabase.local?
        server = MiqServer.my_server
        host   = server.ipaddress if server && server.ipaddress
      end
      host
    end

    def db_disk_size(disk)
      MiqSystem.disk_usage(disk).first[:filesystem]
    rescue RuntimeError => err
      return nil if err.message.include?("does not exist")
      raise
    end
  end

  def seed
    mine = evm_tables.includes(:text_tables, :vmdb_indexes).index_by(&:name)

    self.class.connection.tables.sort.each do |table_name|
      table = mine.delete(table_name)
      VmdbTableEvm.seed_for_database(self, table || table_name)
    end

    mine.each do |name, t|
      _log.info("Table <#{name}> is no longer in Database <#{self.name}> - deleting")
      t.destroy
    end
  end
end
