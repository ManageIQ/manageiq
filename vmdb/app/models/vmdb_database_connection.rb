class VmdbDatabaseConnection < ActiveRecord::Base
  self.table_name = 'pg_stat_activity'
  self.primary_key = nil

  has_many :pg_locks, :primary_key => 'pid', :foreign_key => 'pid'

  default_scope do
    current_database = VmdbDatabaseConnection.connection.current_database
    where(:datname => current_database).includes(:pg_locks)
  end

  virtual_column :address,           :type => :string
  virtual_column :application,       :type => :string
  virtual_column :command,           :type => :string
  virtual_column :spid,              :type => :integer
  virtual_column :task_state,        :type => :string
  virtual_column :wait_resource,     :type => :string
  virtual_column :wait_time,         :type => :integer
  virtual_column :vmdb_database_id,  :type => :integer

  virtual_belongs_to :vmdb_database
  virtual_belongs_to :zone
  virtual_belongs_to :miq_server
  virtual_belongs_to :miq_worker

  virtual_column :pid, :type => :integer
  virtual_column :blocked_by, :type => :integer

  attr_reader :vmdb_database_id

  def vmdb_database_id
    @vmdb_database_id ||= self.class.vmdb_database.id
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
    read_attribute 'pid'
  end

  def task_state
    waiting
  end

  def wait_time
    wait_time_ms
  end

  def wait_resource
    pg_locks.first.relation
  end

  def wait_time_ms
    (Time.now - query_start).to_i
  end

  def blocked_by
    lock_info = pg_locks.where(:granted => false).first
    lock_info && lock_info.blocking_lock.pid
  end

  def to_csv_hash
    {
      'session_id'              => spid,
      'xact_start'              => xact_start,
      'last_request_start_time' => query_start,
      'command'                 => query,
      'task_state'              => waiting,
      'login'                   => usename,
      'application'             => application_name,
      'request_id'              => usesysid,
      'net_address'             => client_addr,
      'host_name'               => client_hostname,
      'client_port'             => client_port,
      'wait_time_ms'            => wait_time_ms,
      'blocked_by'              => blocked_by,
    }
  end

  def vmdb_database
    VmdbDatabase.find_by_id(self.vmdb_database_id)
  end

  def vmdb_database=(db)
    self.vmdb_database_id = db.id
  end

  def miq_worker
    return @miq_worker if defined?(@miq_worker)
    @miq_worker = MiqWorker.find_current_in_my_region.where(:sql_spid => self.spid).first
  end

  def miq_server
    return @miq_server if defined?(@miq_server)
    w = miq_worker
    @miq_server = w ? w.miq_server : MiqServer.find_started_in_my_region.where(:sql_spid => self.spid).first
  end

  def zone
    return @zone if defined?(@zone)
    @zone = miq_server && miq_server.zone
  end

  def pid
    return @pid if defined?(@pid)
    parent = miq_worker || miq_server
    @pid = parent && parent.pid
  end
end
