class RemoveFiltersFromMiqGroups < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_groups, :filters, :text
  end
end
