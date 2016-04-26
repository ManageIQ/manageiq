class AddFiltersToEntitlements < ActiveRecord::Migration[5.0]
  def change
    add_column :entitlements, :filters, :text
  end
end
