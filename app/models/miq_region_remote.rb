class MiqRegionRemote < ApplicationRecord
  def self.db_ping(host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)
    with_remote_connection(host, port, username, password, database, adapter) do |conn|
      return EvmDatabase.ping(conn)
    end
  end

  def self.validate_connection_settings(host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)

    log_details = "Host: [#{host}]}, Database: [#{database}], Adapter: [#{adapter}], User: [#{username}]"

    return [_("Validation failed due to missing port")] if port.blank?
    begin
      with_remote_connection(host, port, username, password, database, adapter) do |c|
        _log.info("Attempting to connection to: #{log_details}...")
        tables = c.tables rescue nil
        if tables
          _log.info("Attempting to connection to: #{log_details}...Successful")

          # Validate the local region against the remote
          region = MiqRegion.my_region
          return [_("Validation failed due to missing region")] if region.nil?
          if region_valid?(region.guid, region.region, host, port, username, password, database, adapter)
            return nil
          else
            return [_("Validation failed because region %{region_name} has already been used") %
                      {:region_name => region.region}]
          end
        else
          _log.info("Attempting to connection to: #{log_details}...Failed")
          return [_("Validation failed")]
        end
      end
    rescue => err
      _log.warn("Attempting to connection to: #{log_details}...Failed with error: '#{err.message}")
      return [_("Validation failed with error: '%{error_message}") % {:error_message => err.message}]
    end
  end

  def self.region_valid?(guid, region, host, port, username, password, database = nil, adapter = nil)
    database, adapter = prepare_default_fields(database, adapter)

    log_header = "Region: [#{region}] with guid: [#{guid}]:"

    with_remote_connection(host, port, username, password, database, adapter) do |conn|
      cond = sanitize_sql_for_conditions(["region = ?", region])
      reg = conn.select_one("SELECT * FROM miq_regions WHERE #{cond}")

      if reg.nil?
        _log.debug("#{log_header} Valid since region #{region} does not exist in remote.")
        return true
      end

      unless reg['guid'] && reg['guid'] != guid
        _log.debug("#{log_header} Valid since region and guid match remote.")
        return true
      end

      _log.warn("#{log_header} Invalid since remote guid is: [#{reg['guid']}].")
      return false
    end
  end

  def self.prepare_default_fields(database, adapter)
    if database.nil? || adapter.nil?
      db_conf = ActiveRecord::Base.configurations[Rails.env]
      database ||= db_conf["database"]
      adapter  ||= db_conf["adapter"]
    end
    return database, adapter
  end

  def self.connection_parameters_for(config)
    host, port, username, password, database, adapter = config.values_at(:host, :port, :username, :password, :database, :adapter)
    database, adapter = prepare_default_fields(database, adapter)
    return host, port, username, password, database, adapter
  end

  def self.with_remote_connection(host, port, username, password, database, adapter, connect_timeout = 0)
    # Don't allow accidental connections to localhost.  A blank host will
    # connect to localhost, so don't allow that at all.
    host = host.to_s.strip
    raise ArgumentError, _("host cannot be blank") if host.blank?
    if [nil, "", "localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
      local_database = ActiveRecord::Base.configurations.fetch_path(Rails.env, "database").to_s.strip
      if database == local_database
        raise ArgumentError, _("host cannot be set to localhost if database matches the local database")
      end
    end

    begin
      pool = establish_connection({
        :adapter         => adapter,
        :host            => host,
        :port            => port,
        :username        => username,
        :password        => password,
        :database        => database,
        :connect_timeout => connect_timeout
      }.delete_blanks)
      conn = pool.connection
      yield conn
    ensure
      remove_connection
    end
  end

  def self.display_name(number = 1)
    n_('Region Remote', 'Region Remotes', number)
  end
end
