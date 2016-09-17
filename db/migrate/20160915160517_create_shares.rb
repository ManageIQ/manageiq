class CreateShares < ActiveRecord::Migration[5.0]
  def change
    create_table :shares do |t|
      t.references :sharer, :type => :bigint
      t.string     :permission_mode
      t.boolean    :block_tenant_inheritance

      t.timestamps
    end

    create_table :share_members do |t|
      t.references :share,    :type => :bigint
      t.references :shareable, :type => :bigint, :polymorphic => true
    end

    create_table :share_receivers do |t|
      t.references :share,  :type => :bigint
      t.references :tenant, :type => :bigint
    end

    # This is a join table, but due to replication we need primary keys and cannot use `create_join_table`
    create_table(:miq_product_features_shares) do |t|
      t.references :miq_product_feature, :type => :bigint
      t.references :share,               :type => :bigint
    end
  end
end
