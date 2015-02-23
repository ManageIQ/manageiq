class PgStatActivity < ActiveRecord::Base
  self.table_name = 'pg_stat_activity'
  self.primary_key = nil

  has_many :pg_locks, :primary_key => 'pid', :foreign_key => 'pid'

  def self.activity_stats
    current_database = connection.current_database
    data = where(:datname => current_database).includes(:pg_locks)
    data.collect do |record|
      conn = {'session_id' => record.pid}
      conn['xact_start']              = record.xact_start
      conn['last_request_start_time'] = record.query_start
      conn['command']                 = record.query
      conn['task_state']              = record.waiting
      conn['login']                   = record.usename
      conn['application']             = record.application_name
      conn['request_id']              = record.usesysid
      conn['net_address']             = record.client_addr
      conn['host_name']               = record.client_hostname
      conn['client_port']             = record.client_port
      conn['wait_time_ms']            = record.wait_time_ms
      conn['blocked_by']              = record.blocked_by

      conn
    end
  end

  def wait_time_ms
    (Time.now - query_start).to_i
  end

  def blocked_by
    lock_info = pg_locks.where(:granted => false).first
    lock_info && lock_info.blocking_lock.pid
  end
end
