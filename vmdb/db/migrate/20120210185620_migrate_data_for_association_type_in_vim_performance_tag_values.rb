require Rails.root.join('lib/migration_helper')

class MigrateDataForAssociationTypeInVimPerformanceTagValues < ActiveRecord::Migration
  include MigrationHelper

  self.no_transaction = true

  def up
    change_data :vim_performance_tag_values, :association_type, 'Vm', 'VmOrTemplate'
  end

  def down
    change_data :vim_performance_tag_values, :association_type, 'VmOrTemplate', 'Vm'
  end
end
