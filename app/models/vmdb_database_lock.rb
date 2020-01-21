class VmdbDatabaseLock < ApplicationRecord
  self.table_name = 'pg_locks'
  self.primary_key = nil

  def blocking_lock
    return unless granted == false
    blocking_lock_relation.where(:granted => true)
      .find_by(['pid != ?', pid])
  end

  def self.display_name(number = 1)
    n_('Database Lock', 'Database Locks', number)
  end

  private

  def blocking_lock_relation
    case locktype
    when "relation"
      self.class.where(:relation => relation, :database => database)
    when "advisory"
      self.class.where(:classid => classid, :objid => objid, :objsubid => objsubid)
    when "virtualxid"
      self.class.where(:virtualxid => virtualxid)
    when "transactionid"
      self.class.where(:transactionid => transactionid)
    when "tuple"
      self.class.where(:database => database,
                       :relation => relation,
                       :page     => page,
                       :tuple    => tuple)
    end
  end
end
