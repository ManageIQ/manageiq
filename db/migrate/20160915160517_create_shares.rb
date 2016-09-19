class CreateShares < ActiveRecord::Migration[5.0]
  def change
    create_table :shares do |t|
      t.references :resource, :type => :bigint, :polymorphic => true
      t.references :tenant,   :type => :bigint
      t.references :user,     :type => :bigint
      t.boolean    :allow_tenant_inheritance
      t.timestamps
    end

    create_table :miq_product_features_shares do |t|
      t.references :miq_product_feature, :type => :bigint
      t.references :share,               :type => :bigint
    end
  end
end
