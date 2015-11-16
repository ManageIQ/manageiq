class CreateEndpoints < ActiveRecord::Migration
  def change
    create_table :endpoints do |t|
      t.string     :role
      t.string     :ipaddress
      t.string     :hostname
      t.integer    :port
      t.belongs_to :resource, :polymorphic => true, :type => :bigint

      t.timestamps :null => false
    end
  end
end
