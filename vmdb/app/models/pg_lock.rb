class PgLock < ActiveRecord::Base
  self.primary_key = nil

  def blocking_lock
    return unless granted == false
    blocking_lock_relation.where(:granted => true)
    .where(['pid != ?', pid]).limit(1).first
  end

  private

  def blocking_lock_relation
    case locktype
    when "relation"
      PgLock.where(:relation => relation, :database => database)
    when "advisory"
      PgLock.where(:classid => classid, :objid => objid, :objsubid => objsubid)
    when "virtualxid"
      PgLock.where(:virtualxid => virtualxid)
    when "transactionid"
      PgLock.where(:transactionid => transactionid)
    when "tuple"
      PgLock.where(:database => database,
                   :relation => relation,
                   :page     => page,
                   :tuple    => tuple)
    end
  end
end
