class PgLock < ActiveRecord::Base
  self.primary_key = nil

  def blocking_lock
    blocking_lock_relation.where(['pid != ?', pid]).limit(1).first
  end

  private

  def blocking_lock_relation
    case locktype
    when "relation"
      PgLock.where(:relation => relation, :database => database)
    end
  end
end
