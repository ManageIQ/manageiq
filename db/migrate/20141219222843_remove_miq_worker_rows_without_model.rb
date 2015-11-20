class RemoveMiqWorkerRowsWithoutModel < ActiveRecord::Migration
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time "Remove MiqWorker records where the model was removed" do
      types = %w(MiqWorkerMonitor MiqStorageStatsCollectorWorker MiqPerfCollectorWorker MiqPerfProcessorWorker)
      MiqWorker.where(:type => types).delete_all
    end
  end
end
