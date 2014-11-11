require Rails.root.join('lib/migration_helper')

class ConvertRubyrepDataForVimPerformancesToMetricsSubtablesOnPostgres < ActiveRecord::Migration
  # NOTE: This migration is reentrant so that any failures in the middle of the
  # data migration do not rollback the entire set, and so that not all of the
  # data is migrated in a single transaction.

  include MigrationHelper
  include MigrationHelper::SharedStubs

  disable_ddl_transaction!

  class VimPerformance < ActiveRecord::Base; end

  class Configuration < ActiveRecord::Base
    serialize   :settings
  end

  class MiqRegionRemote < ActiveRecord::Base
    def self.with_remote_connection(host, port, username, password, database, adapter)
      # Don't allow accidental connections to localhost.  A blank host will
      # connect to localhost, so don't allow that at all.
      host = host.to_s.strip
      raise ArgumentError, "host cannot be blank" if host.blank?
      if ["localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
        local_database = VMDB::Config.new("database").config.fetch_path(Rails.env.to_sym, :database).to_s.strip
        raise ArgumentError, "host cannot be set to localhost if database matches the local database" if database == local_database
      end

      port ||= 5432 if adapter == "postgresql"
      pool = self.establish_connection(
        :adapter  => adapter,
        :host     => host,
        :port     => port,
        :username => username,
        :password => password,
        :database => database
      )
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

  def up
    return unless postgresql? && VimPerformance.table_exists? && RrPendingChange.table_exists?

    say_with_time("Converting vim_performances records in #{RrPendingChange.table_name}") do
      rows = RrPendingChange.count(:conditions => {:change_table => "vim_performances"})
      say_batch_started(rows)
      return if rows == 0

      remote_settings = discover_replication_settings
      say("Replication destination is not configured.  Skipping Remote data migration", :subitem) if remote_settings.nil?

      rrpc_table  = connection.quote_table_name(RrPendingChange.table_name)

      loop do
        batch = RrPendingChange.all(:conditions => {:change_table => "vim_performances"}, :limit => 10000)
        break if batch.empty?

        vp_ids_to_rrpcs = batch.group_by { |rrpc| rrpc.change_key.split("|").last.to_i }
        vp_ids = vp_ids_to_rrpcs.keys
        vps    = VimPerformance.find_all_by_id(vp_ids)

        # For any pending changes that have deleted vim_performances, delete
        # the remote vim_performances, then delete the local pending changes
        deleted_vp_ids = vp_ids - vps.collect(&:id)
        unless deleted_vp_ids.empty?
          rrpcs_to_delete    = vp_ids_to_rrpcs.values_at(*deleted_vp_ids).flatten
          rrpc_ids_to_delete = rrpcs_to_delete.collect(&:id)

          conditions = sanitize_sql_for_conditions({:id => rrpc_ids_to_delete}, :vim_performances)

          if remote_settings
            MiqRegionRemote.with_remote_connection(*remote_settings) do |c|
              c.execute("DELETE FROM vim_performances WHERE #{conditions}")
            end
          end

          conditions = sanitize_sql_for_conditions({:id => rrpc_ids_to_delete}, rrpc_table)
          connection.execute("DELETE FROM #{rrpc_table} WHERE #{conditions}")
        end

        # For all other pending changes, determine the new subtable into which
        # they should go, and update the pending change record.
        month_to_vps = vps.group_by { |vp| vp.timestamp.month }
        month_to_vps.each do |month, vps_for_month|
          rrpcs_for_month    = vp_ids_to_rrpcs.values_at(*vps_for_month.collect(&:id)).flatten
          rrpc_ids_for_month = rrpcs_for_month.collect(&:id)

          subtable   = connection.quote(subtable_name(:metric_rollups, month))
          conditions = sanitize_sql_for_conditions({:id => rrpc_ids_for_month}, rrpc_table)
          connection.execute("UPDATE #{rrpc_table} SET change_table = #{subtable} WHERE #{conditions}")
        end

        say_batch_processed(batch.length)
      end
    end
  end

  def down
    return unless postgresql? && RrPendingChange.table_exists?
  end

  def subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  def discover_replication_settings
    configs = Configuration.where(:typ => 'vmdb').select(:settings).all

    settings = nil
    configs.each do |c|
      next unless c.settings.kind_of?(Hash)
      hash = vmdb_config_symbolize(c.settings)
      destination = hash.fetch_path(:workers, :worker_base, :replication_worker, :replication, :destination)
      if destination && !destination[:host].blank?
        settings = destination
        break
      end
    end

    settings && connection_parameters_for(settings)
  end

  private

  def vmdb_config_symbolize(h)
    ret = eval(h.inspect)
    ret = YAML::load(ret) if ret.is_a?(String) && ret =~ /^---/
    ret.each_key {|k| ret[k].symbolize_keys!}.symbolize_keys!
  end

  def connection_parameters_for(config)
    host, port, username, password, database, adapter = config.values_at(:host, :port, :username, :password, :database, :adapter)
    database, adapter = prepare_default_fields(database, adapter)
    return host, port, username, password, database, adapter
  end

  def prepare_default_fields(database, adapter)
    if database.nil? || adapter.nil?
      db_conf = VMDB::Config.new("database").config[Rails.env.to_sym]
      database ||= db_conf[:database]
      adapter  ||= db_conf[:adapter]
    end
    return database, adapter
  end

end
