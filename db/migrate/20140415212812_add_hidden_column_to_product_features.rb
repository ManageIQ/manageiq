class AddHiddenColumnToProductFeatures < ActiveRecord::Migration[4.2]
  def change
    add_column :miq_product_features, :hidden, :boolean
  end
end
