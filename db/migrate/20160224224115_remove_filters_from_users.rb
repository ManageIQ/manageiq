class RemoveFiltersFromUsers < ActiveRecord::Migration[5.0]
  def change
    remove_column :users, :filters, :text
  end
end
