class RemoveReplicatedRowsFromNewlyExcludedTables < ActiveRecord::Migration[4.2]
  class MiqEventDefinition < ActiveRecord::Base; end

  class ScanItem < ActiveRecord::Base; end

  class Configuration < ActiveRecord::Base
    serialize :settings, Hash
  end

  def up
    say_with_time("Removing rows from newly excluded tables") do
      region_cond = anonymous_class_with_id_regions.region_to_conditions(anonymous_class_with_id_regions.my_region_number)
      MiqEventDefinition.where.not(region_cond).delete_all
      ScanItem.where.not(region_cond).delete_all
    end

    say_with_time("Adding tables to replication worker exclude list") do
      Configuration.where(:typ => "vmdb").each do |c|
        c.settings.deep_symbolize_keys![:workers][:worker_base][:replication_worker][:replication][:exclude_tables] <<
          MiqEventDefinition.table_name << ScanItem.table_name
        c.save!
      end
    end
  end
end
