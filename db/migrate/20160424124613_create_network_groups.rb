class CreateNetworkGroups < ActiveRecord::Migration
  def change
    create_table :network_groups do |t|
      t.string     :ems_ref
      t.string     :name
      t.string     :cidr
      t.string     :status
      t.boolean    :enabled
      t.belongs_to :ems,                          :type => :bigint
      t.belongs_to :orchestration_stack,          :type => :bigint
      t.string     :type
    end

    add_index :network_groups, :ems_id
    add_index :network_groups, :orchestration_stack_id
  end
end
