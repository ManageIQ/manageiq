class RemoveReplicatedRowsFromNewlyExcludedTables < ActiveRecord::Migration
  class MiqEventDefinition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ScanItem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Configuration < ActiveRecord::Base
    serialize :settings, Vmdb::ConfigurationEncoder
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Removing rows from newly excluded tables") do
      region_cond = ActiveRecord::Base.region_to_conditions(ActiveRecord::Base.my_region_number)
      MiqEventDefinition.where.not(region_cond).delete_all
      ScanItem.where.not(region_cond).delete_all
    end

    say_with_time("Adding tables to replication worker exclude list") do
      Configuration.where(:typ => "vmdb").each do |c|
        c.settings[:workers][:worker_base][:replication_worker][:replication][:exclude_tables] << MiqEventDefinition.table_name << ScanItem.table_name
        c.save!
      end
    end
  end
end
