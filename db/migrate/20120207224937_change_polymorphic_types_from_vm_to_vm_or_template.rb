require Rails.root.join('lib/migration_helper')

class ChangePolymorphicTypesFromVmToVmOrTemplate < ActiveRecord::Migration
  include MigrationHelper

  disable_ddl_transaction!

  COLUMNS_TO_UPDATE = [
    # Table              Column             Index on the column
    [:miq_requests,      :source_type,      [:source_id, :source_type]],
    [:miq_requests,      :destination_type, [:destination_id, :destination_type]],
    [:miq_request_tasks, :source_type,      [:source_id, :source_type]],
    [:miq_request_tasks, :destination_type, [:destination_id, :destination_type]],
  ]

  def up
    COLUMNS_TO_UPDATE.each do |table, column, index|
      remove_index(table, index) if index_exists?(table, index)
      change_data(table, column, 'Vm', 'VmOrTemplate')
      add_index(table, index)
    end
  end

  def down
    COLUMNS_TO_UPDATE.each do |table, column, index|
      remove_index(table, index) if index_exists?(table, index)
      change_data(table, column, 'VmOrTemplate', 'Vm')
      add_index(table, index)
    end
  end
end
