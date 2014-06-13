class MiqRegionRemote < ActiveRecord::Base
  def self.db_ping(host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)
    self.with_remote_connection(host, port, username, password, database, adapter) do |conn|
      return EvmDatabase.ping(conn)
    end
  end

  def self.destroy_entire_region(region, host, port, username, password, database = nil, adapter = nil, tables = nil)
    database, adapter = prepare_default_fields(database, adapter)

    log_header = "MIQ(MiqRegionRemote.destroy_entire_region)"

    self.with_remote_connection(host, port, username, password, database, adapter) do |conn|
      $log.info "#{log_header} Clearing region [#{region}] from remote host [#{host}]..."

      tables ||= conn.tables.reject {|t| t =~ /^schema_migrations|^rr/}.sort
      tables.each do |t|
        pk = conn.primary_key(t)
        if pk
          conditions = sanitize_conditions(self.region_to_conditions(region, pk))
        else
          id_cols = connection.columns(t).select { |c| c.name.ends_with?("_id") }
          conditions = id_cols.collect { |c| "(#{sanitize_conditions(self.region_to_conditions(region, c.name))})" }.join(" OR ")
        end

        rows = conn.delete("DELETE FROM #{t} WHERE #{conditions}")
        $log.info "#{log_header} Cleared [#{rows}] rows from table [#{t}]"
      end

      $log.info "#{log_header} Clearing region [#{region}] from remote host [#{host}]...Complete"
    end
  end

  def self.validate_connection_settings(host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)

    log_header  = "MIQ(MiqRegionRemote.validate_connection_settings)"
    log_details = "Host: [#{host}]}, Database: [#{database}], Adapter: [#{adapter}], User: [#{username}]"

    begin
      self.with_remote_connection(host, port, username, password, database, adapter) do |c|
        $log.info("#{log_header} Attempting to connection to: #{log_details}...")
        tables = c.tables rescue nil
        if tables
          $log.info("#{log_header} Attempting to connection to: #{log_details}...Successful")

          # Validate the local region against the remote
          region = MiqRegion.my_region
          return ["Validation failed due to missing region"] if region.nil?
          return self.region_valid?(region.guid, region.region, host, port, username, password, database, adapter) ? nil : ["Validation failed because region #{region.region} has already been used"]
        else
          $log.info("#{log_header} Attempting to connection to: #{log_details}...Failed")
          return ["Validation failed"]
        end
      end
    rescue => err
      $log.warn("#{log_header} Attempting to connection to: #{log_details}...Failed with error: '#{err.message}")
      return ["Validation failed with error: '#{err.message}"]
    end
  end

  def self.region_valid?(guid, region, host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)

    log_header = "MIQ(MiqRegionRemote.region_valid?) Region: [#{region}] with guid: [#{guid}]:"

    self.with_remote_connection(host, port, username, password, database, adapter) do |conn|
      cond = sanitize_conditions(["region = ?", region])
      reg = conn.select_one("SELECT * FROM miq_regions WHERE #{cond}")

      if reg.nil?
        $log.debug("#{log_header} Valid since region #{region} does not exist in remote.")
        return true
      end

      unless reg['guid'] && reg['guid'] != guid
        $log.debug("#{log_header} Valid since region and guid match remote.")
        return true
      end

      $log.warn("#{log_header} Invalid since remote guid is: [#{reg['guid']}].")
      return false
    end
  end

  def self.prepare_default_fields(database, adapter)
    if database.nil? || adapter.nil?
      db_conf = VMDB::Config.new("database").config[Rails.env.to_sym]
      database ||= db_conf[:database]
      adapter  ||= db_conf[:adapter]
    end
    return database, adapter
  end

  def self.connection_parameters_for(config)
    host, port, username, password, database, adapter = config.values_at(:host, :port, :username, :password, :database, :adapter)
    database, adapter = prepare_default_fields(database, adapter)
    return host, port, username, password, database, adapter
  end

  def self.with_remote_connection(host, port, username, password, database, adapter)
    # Don't allow accidental connections to localhost.  A blank host will
    # connect to localhost, so don't allow that at all.
    host = host.to_s.strip
    raise ArgumentError, "host cannot be blank" if host.blank?
    if [nil, "", "localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
      local_database = VMDB::Config.new("database").config.fetch_path(Rails.env.to_sym, :database).to_s.strip
      raise ArgumentError, "host cannot be set to localhost if database matches the local database" if database == local_database
    end

    pool = establish_connection({
      :adapter  => adapter,
      :host     => host,
      :port     => port,
      :username => username,
      :password => password,
      :database => database
    }.delete_blanks)
    begin
      conn = pool.connection
      yield conn
    ensure
      # Disconnect and remove this new connection from the connection pool, to completely clear it out
      conn.disconnect! if conn
      ActiveRecord::Base.connection_handler.connection_pools.delete(self.name)
    end
  end
end
