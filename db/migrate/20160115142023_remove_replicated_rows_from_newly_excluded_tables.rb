class RemoveReplicatedRowsFromNewlyExcludedTables < ActiveRecord::Migration
  class MiqEventDefinition < ActiveRecord::Base; end

  class ScanItem < ActiveRecord::Base; end

  class Configuration < ActiveRecord::Base
    serialize :settings, Hash
  end

  def up
    say_with_time("Removing rows from newly excluded tables") do
      ar_region_class = ArRegion.anonymous_class_with_ar_region
      region_cond = ar_region_class.region_to_conditions(ar_region_class.my_region_number)
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
