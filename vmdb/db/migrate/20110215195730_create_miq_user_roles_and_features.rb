class CreateMiqUserRolesAndFeatures < ActiveRecord::Migration
  def self.up
    create_table :miq_product_features do |t|
      t.string        :identifier
      t.string        :name
      t.string        :description
      t.string        :feature_type
      t.boolean       :protected, :default => false
      t.bigint        :parent_id

      t.timestamps
    end

    create_table :miq_user_roles do |t|
      t.string        :name
      t.boolean       :read_only

      t.timestamps
    end

    create_table :miq_roles_features, :id => false do |t|
      t.bigint :miq_user_role_id
      t.bigint :miq_product_feature_id
    end

    add_column :miq_groups,   :miq_user_role_id, :bigint
  end

  def self.down
    remove_column :miq_groups,   :miq_user_role_id

    drop_table :miq_roles_features
    drop_table :miq_user_roles
    drop_table :miq_product_features
  end
end
