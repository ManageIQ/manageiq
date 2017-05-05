class DropArbitrationTables < ActiveRecord::Migration[5.0]
  def change
    drop_table :arbitration_settings do |t|
      t.string :name
      t.string :display_name
      t.text :value
      t.datetime :created_on
      t.datetime :updated_on
    end

    drop_table :arbitration_rules do |t|
      t.string :description
      t.string :operation
      t.integer :arbitration_profile_id
      t.integer :priority
      t.text :expression

      t.timestamps
    end

    drop_table :arbitration_profiles do |t|
      t.string :uid_ems
      t.string :name
      t.string :type
      t.boolean :profile
      t.text :description
      t.boolean :default_profile

      t.belongs_to :cloud_network, :type => :bigint
      t.belongs_to :flavor, :type => :bigint
      t.belongs_to :availability_zone, :type => :bigint
      t.belongs_to :cloud_subnet, :type => :bigint
      t.belongs_to :security_group, :type => :bigint
      t.belongs_to :ems, :type => :bigint
      t.belongs_to :authentication, :type => :bigint

      t.timestamps
    end
  end
end
