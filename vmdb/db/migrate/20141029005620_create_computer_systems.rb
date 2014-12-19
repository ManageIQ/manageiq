class CreateComputerSystems < ActiveRecord::Migration
  def up
    create_table :computer_systems do |t|
      t.belongs_to :managed_entity, :type => :bigint, :polymorphic => true
      t.timestamps
    end
    add_index :computer_systems,  [:managed_entity_id, :managed_entity_type],
              :name => :computer_systems_managed_entity_i1

    add_column :hardwares,         :computer_system_id, :bigint
    add_index  :hardwares,         :computer_system_id
    add_column :operating_systems, :computer_system_id, :bigint
    add_index  :operating_systems, :computer_system_id
  end

  def down
    remove_column :hardwares,         :computer_system_id
    remove_column :operating_systems, :computer_system_id

    drop_table :computer_systems
  end
end
