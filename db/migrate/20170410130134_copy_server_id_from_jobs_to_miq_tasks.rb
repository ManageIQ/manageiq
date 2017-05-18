class CopyServerIdFromJobsToMiqTasks < ActiveRecord::Migration[5.0]
  class Job < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiqTask < ActiveRecord::Base; end

  def up
    say_with_time("Copying miq_server_id from jobs table to miq_tasks") do
      Job.where.not(:miq_task_id => nil).find_each do |job|
        MiqTask.find(job.miq_task_id).update_attributes!(:miq_server_id => job.miq_server_id)
      end
    end
  end

  def down
    say_with_time("nullifying miq_server_id column on miq_tasks table") do
      MiqTask.update_all(:miq_server_id => nil)
    end
  end
end
