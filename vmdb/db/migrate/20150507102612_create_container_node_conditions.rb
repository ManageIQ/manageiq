class CreateContainerNodeConditions < ActiveRecord::Migration
  def up
    create_table :container_node_conditions do |t|
      t.belongs_to :container_node, :type => :bigint
      t.string     :name
      t.string     :status
      t.timestamp  :last_heartbeat_time, :null => true
      t.timestamp  :last_transition_time, :null => true
      t.string     :reason
      t.string     :message
    end
  end

  def down
    drop_table :container_node_conditions
  end
end
