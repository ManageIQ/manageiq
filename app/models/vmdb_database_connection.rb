class VmdbDatabaseConnection < ApplicationRecord
  self.table_name = 'pg_stat_activity'
  # a little wierd since the self.pid != self["pid"] ( self.spid == self["pid"])
  self.primary_key = 'pid'

  has_many :vmdb_database_locks, :primary_key => 'pid', :foreign_key => 'pid'

  default_scope do
    current_database = VmdbDatabaseConnection.connection.current_database
    where(:datname => current_database).includes(:vmdb_database_locks)
  end

  virtual_column :address,           :type => :string
  virtual_column :application,       :type => :string
  virtual_column :command,           :type => :string
  virtual_column :spid,              :type => :integer
  virtual_column :wait_resource,     :type => :integer  # oid
  virtual_column :wait_time,         :type => :integer

  virtual_belongs_to :zone
  virtual_belongs_to :miq_server
  virtual_belongs_to :miq_worker

  virtual_column :pid, :type => :integer
  virtual_column :blocked_by, :type => :integer

  def self.log_statistics(output = $log)
    log_activity(output)
    log_table_size(output)
    log_table_statistics(output)
  end

  def self.log_csv(keys, stats, label, output)
    require 'csv'
    csv = CSV.generate do |rows|
      rows << keys
      stats.each { |s| rows << s.values_at(*keys) }
    end

    output.info("MIQ(#{name}.#{__method__}) <<-#{label}\n#{csv}#{label}")
  end

  def self.log_activity(output = $log)
    stats = all.map(&:to_csv_hash)
    log_csv(stats.first.keys, stats, "ACTIVITY_STATS_CSV", output)
  rescue => err
    output.warn("MIQ(#{name}.#{__method__}) Unable to log activity, '#{err.message}'")
  end

  def self.log_table_size(output = $log)
    stats = ApplicationRecord.connection.table_size
    log_csv(stats.first.keys, stats, "TABLE_SIZE_CSV", output)
  rescue => err
    output.warn("MIQ(#{name}.#{__method__}) Unable to log activity, '#{err.message}'")
  end

  def self.log_table_statistics(output = $log)
    stats = ApplicationRecord.connection.table_statistics
    log_csv(stats.first.keys, stats, "TABLE_STATS_CSV", output)
  rescue => err
    output.warn("MIQ(#{name}.#{__method__}) Unable to log activity, '#{err.message}'")
  end

  def address
    client_addr
  end

  def application
    application_name
  end

  def command
    query
  end

  def spid
    read_attribute('pid')
  end

  def wait_time
    wait_time_ms
  end

  def wait_resource
    lock = vmdb_database_locks.first
    lock && lock.relation
  end

  def wait_time_ms
    return 0 if query_start.nil?

    (Time.now - query_start).to_i
  end

  def blocked_by
    lock_info = vmdb_database_locks.find_by(:granted => false)
    lock_info && lock_info.blocking_lock.pid
  end

  def to_csv_hash
    {
      'session_id'              => spid,
      'xact_start'              => xact_start,
      'last_request_start_time' => query_start,
      'command'                 => query,
      'login'                   => usename,
      'application'             => application_name,
      'request_id'              => usesysid,
      'net_address'             => client_addr,
      'host_name'               => client_hostname,
      'client_port'             => client_port,
      'wait_event_type'         => wait_event_type,
      'wait_event'              => wait_event,
      'wait_time_ms'            => wait_time_ms,
      'blocked_by'              => blocked_by
    }
  end

  def miq_worker
    @miq_worker ||= MiqWorker.find_current_in_my_region.find_by(:sql_spid => spid)
  end

  def miq_server
    @miq_server ||= miq_worker.try(:miq_server) || MiqServer.active_miq_servers.in_my_region.find_by(:sql_spid => spid)
  end

  def zone
    @zone ||= miq_server.try(:zone)
  end

  def pid
    @pid ||= (miq_worker || miq_server).try(:pid)
  end

  def self.display_name(number = 1)
    n_('Database Connection', 'Database Connections', number)
  end
end
