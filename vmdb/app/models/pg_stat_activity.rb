class PgStatActivity < ActiveRecord::Base
  self.table_name = 'pg_stat_activity'
  self.primary_key = nil

  has_many :pg_locks, :primary_key => 'pid', :foreign_key => 'pid'

  def wait_time_ms
    (Time.now - query_start).to_i
  end
end
