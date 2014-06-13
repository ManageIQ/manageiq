class ChangeIndexOnMiqQueueV2 < ActiveRecord::Migration
  def up
    remove_index :miq_queue, :name => "miq_queue_idx"

    # MiqQueue.find_by_task_id
    add_index :miq_queue, :task_id

    # query for GET/PEEK
    execute "CREATE INDEX miq_queue_get_idx ON miq_queue(queue_name, zone, role, server_guid, priority, deliver_on, task_id) WHERE state = 'ready'"

    # sub query for GET
    execute "CREATE INDEX miq_queue_get_sub_idx on miq_queue(task_id, zone) WHERE state = 'dequeue' AND task_id IS NOT NULL"

    # query for put_updates
    add_index :miq_queue, %w(class_name method_name queue_name state zone), :name => 'miq_queue_put_idx'
  end

  def down
    remove_index :miq_queue, :task_id
    remove_index :miq_queue, :name => 'miq_queue_get_idx'
    remove_index :miq_queue, :name => "miq_queue_get_sub_idx"
    remove_index :miq_queue, :name => "miq_queue_put_idx"

    add_index :miq_queue, [:state, :zone, :task_id, :queue_name, :role, :server_guid, :deliver_on, :priority, :id], :name => "miq_queue_idx"
  end
end
