class RemoveDeletedTablesFromReplicationSettings < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    serialize :value
  end

  def up
    deleted_tables = %w(miq_events miq_license_contents vim_performances)

    changes = SettingsChange.where(:key => "/workers/worker_base/replication_worker/replication/exclude_tables")
    changes.each do |change|
      change.value -= deleted_tables
      change.save
    end
  end
end
