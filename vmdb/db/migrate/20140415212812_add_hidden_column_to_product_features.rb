class AddHiddenColumnToProductFeatures < ActiveRecord::Migration
  def change
    add_column :miq_product_features, :hidden, :boolean
  end
end
