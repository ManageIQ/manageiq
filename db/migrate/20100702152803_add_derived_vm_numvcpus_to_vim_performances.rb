require Rails.root.join('lib/migration_helper')

class AddDerivedVmNumvcpusToVimPerformances < ActiveRecord::Migration
  include MigrationHelper::PerformancesViews

  def up
    add_column    :vim_performances,  :derived_vm_numvcpus, :float

    drop_performances_views
    create_performances_views
  end

  def down
    drop_performances_views

    remove_column :vim_performances,  :derived_vm_numvcpus

    create_performances_views
  end
end
