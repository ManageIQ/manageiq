class AddFiltersToEntitlements < ActiveRecord::Migration[5.0]
  def change
    add_column :entitlements, :tag_filters,      :text, :array => true, :default => []
    add_column :entitlements, :resource_filters, :text, :array => true, :default => []
  end
end
