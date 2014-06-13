class RemoveReservesValuesForMiqWorkerSqlSpid < ActiveRecord::Migration
  class Reserve < ActiveRecord::Base
    serialize :reserved
  end

  def up
    say_with_time("Remove reserves values for MiqWorker#sql_spid") do
      Reserve.where(:resource_type => "MiqWorker").each do |r|
        reserved = r.reserved
        if !reserved.kind_of?(Hash) || (reserved.length == 1 && reserved.keys.first == :sql_spid)
          r.destroy
        else
          r.reserved.delete(:sql_spid)
          r.save!
        end
      end
    end
  end

  def down
  end
end
