module VmdbDatabase::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed
      transaction do
        seed_self.tap do
          seed_tables
          seed_indexes
        end
      end
    end

    private

    def seed_self
      (my_database || new).tap do |db|
        data_directory = connection.try(:data_directory)
        disk_size      = db_disk_size(data_directory) if data_directory && EvmDatabase.local?

        db.name            = connection.current_database
        db.vendor          = connection.adapter_name
        db.version         = connection.database_version
        db.ipaddress       = db_server_ipaddress
        db.data_directory  = data_directory
        db.last_start_time = connection.try(:last_start_time)
        db.data_disk       = disk_size

        if db.changed?
          _log.info("#{db.new_record? ? "Creating" : "Updating"} VmdbDatabase #{db.name.inspect}")
          db.save!
        end
      end
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

    def seed_tables
      db = my_database
      vmdb_tables = db.vmdb_tables.index_by(&:name)

      table_names = connection.tables
      tables = table_names.zip([]).to_h
      tables.merge!(connection.text_table_names.slice(*table_names))

      tables.each do |t, tt|
        table   = vmdb_tables.delete(t)
        table ||= VmdbTableEvm.create!(:name => t, :vmdb_database => db) do
          _log.info("Creating VmdbTableEvm #{t.inspect}")
        end

        next unless tt

        text_table   = vmdb_tables.delete(tt)
        text_table ||= VmdbTableText.new

        text_table.attributes = {:name => tt, :evm_table => table, :vmdb_database => db}
        if text_table.new_record? || text_table.changed?
          _log.info("#{text_table.new_record? ? "Creating" : "Updating"} VmdbTableText #{tt.inspect} for VmdbTableEvm #{t.inspect}")
          text_table.save!
        end
      end

      if vmdb_tables.any?
        _log.info("Deleting the following VmdbTable(s) as they no longer exist: #{vmdb_tables.keys.sort.collect(&:inspect).join(", ")}")
        VmdbTable.delete(vmdb_tables.values.map(&:id))
      end
    end

    def seed_indexes
      db = my_database
      vmdb_tables  = db.vmdb_tables.select(:id, :name).index_by(&:name)
      vmdb_indexes = db.vmdb_indexes.index_by(&:name)

      indexes = connection.index_names.slice(*vmdb_tables.keys)

      indexes.each do |t, is|
        is.each do |i|
          index   = vmdb_indexes.delete(i)
          index ||= VmdbIndex.new

          index.attributes = {:name => i, :vmdb_table => vmdb_tables[t]}
          if index.new_record? || index.changed?
            _log.info("#{index.new_record? ? "Creating" : "Updating"} VmdbIndex #{i.inspect} for VmdbTable #{t.inspect}")
            index.save!
          end
        end
      end

      if vmdb_indexes.any?
        _log.info("Deleting the following VmdbIndex(es) as they no longer exist: #{vmdb_indexes.keys.sort.collect(&:inspect).join(", ")}")
        VmdbIndex.delete(vmdb_indexes.values.map(&:id))
      end
    end
  end
end
