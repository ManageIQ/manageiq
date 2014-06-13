class MakePolymorphicHandlerInMiqQueue < ActiveRecord::Migration
  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"
  end

  def self.up
    add_column    :miq_queue, :handler_type, :string
    rename_column :miq_queue, :miq_worker_id, :handler_id

    # Any messages with non-blank miq_worker_id should be an MiqWorker (the others were MiqServer)
    say_with_time("Update MiqQueue handler_type") do
      t = MiqQueue.arel_table
      MiqQueue.where(t[:handler_id].not_eq(nil)).update_all(:handler_type => 'MiqWorker')
    end
  end

  def self.down
    # Any messages that have handlers that are not MiqWorkers should be nil-ed out, as they are probably MiqServers
    say_with_time("Update MiqQueue handler_id") do
      t = MiqQueue.arel_table
      MiqQueue.where(t[:handler_type].eq(nil).or t[:handler_type].not_eq 'MiqWorker').update_all(:handler_id => nil)
    end

    remove_column :miq_queue, :handler_type
    rename_column :miq_queue, :handler_id, :miq_worker_id
  end
end
