class RemoveMiqWorkerRowsWithoutModel < ActiveRecord::Migration
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    types = %w(MiqWorkerMonitor MiqStorageStatsCollectorWorker MiqPerfCollectorWorker MiqPerfProcessorWorker)
    MiqWorker.where(:type => types).delete_all
  end

  def down
    # NO-OP
  end
end
