class RemoveFiltersFromMiqGroups < ActiveRecord::Migration[5.0]
  include MigrationHelper

  def change
    return if previously_migrated_as?("20160414132130")
    remove_column :miq_groups, :filters, :text
  end
end
