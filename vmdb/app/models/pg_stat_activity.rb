class PgStatActivity < ActiveRecord::Base
  self.table_name = 'pg_stat_activity'
  self.primary_key = nil

  has_many :pg_locks, :primary_key => 'pid', :foreign_key => 'pid'

  def self.find_activity
    current_database = connection.current_database
    where(:datname => current_database).includes(:pg_locks)
  end

  def to_csv_hash
    {
      'session_id'              => pid,
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

  def wait_time_ms
    (Time.now - query_start).to_i
  end

  def blocked_by
    lock_info = pg_locks.where(:granted => false).first
    lock_info && lock_info.blocking_lock.pid
  end
end
