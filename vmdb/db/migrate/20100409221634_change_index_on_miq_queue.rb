class ChangeIndexOnMiqQueue < ActiveRecord::Migration
  def self.up
    remove_index :miq_queue, :queue_name
    remove_index :miq_queue, :role
    remove_index :miq_queue, :server_guid
    remove_index :miq_queue, :state
    remove_index :miq_queue, :task_id
    remove_index :miq_queue, :zone

    if connection.adapter_name == "MySQL"
      # Handle issue where MySQL has a limited key size
      say_with_time('add_index(:miq_queue, [:state (100), :zone (100), :task_id, :queue_name (100), :role (100), :server_guid, :deliver_on, :priority, :id], {:name=>"miq_queue_idx"})') do
        connection.execute("CREATE INDEX `miq_queue_idx` ON `miq_queue` (`state` (100), `zone` (100), `task_id`, `queue_name` (100), `role` (100), `server_guid`, `deliver_on`, `priority`, `id`)")
      end
    else
      add_index :miq_queue, [:state, :zone, :task_id, :queue_name, :role, :server_guid, :deliver_on, :priority, :id], :name => "miq_queue_idx"
    end
  end

  def self.down
    remove_index :miq_queue, :name => "miq_queue_idx"

    add_index :miq_queue, :queue_name
    add_index :miq_queue, :role
    add_index :miq_queue, :server_guid
    add_index :miq_queue, :state
    add_index :miq_queue, :task_id
    add_index :miq_queue, :zone
  end
end
