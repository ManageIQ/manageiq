class CreateArbitrationDefaults < ActiveRecord::Migration[5.0]
  def change
    create_table :arbitration_defaults do |t|
      t.string :uid_ems

      t.belongs_to :cloud_network, :type => :bigint
      t.belongs_to :flavor, :type => :bigint
      t.belongs_to :availability_zone, :type => :bigint
      t.belongs_to :cloud_subnet, :type => :bigint
      t.belongs_to :security_group, :type => :bigint
      t.belongs_to :ems, :type => :bigint
      t.belongs_to :authentication, :type => :bigint
    end
  end
end
