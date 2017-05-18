class AddDescriptionAndInterpolatedValueToCustomAttribute < ActiveRecord::Migration[4.2]
  def change
    add_column :custom_attributes, :description, :text
    add_column :custom_attributes, :value_interpolated, :text
  end
end
