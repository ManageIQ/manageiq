class RenameWaitingToStartStateToQueuedinMiqTask < ActiveRecord::Migration[5.0]
  class Job < ActiveRecord::Base
    belongs_to :miq_task, :class_name =>'RenameWaitingToStartStateToQueuedinMiqTask::MiqTask'
    self.inheritance_column = :_type_disabled
  end

  class MiqTask < ActiveRecord::Base
    has_one :job, :class_name => 'RenameWaitingToStartStateToQueuedinMiqTask::Job'
  end

  def up
    say_with_time("updating 'state' attribute of 'miq_tasks' table from 'Waiting_to_start' to 'Queued'") do
      MiqTask.where(:state => "Waiting_to_start").update_all(:state => "Queued")
    end
  end

  def down
    say_with_time("updating 'state' of 'miq_tasks' from 'Queued' to 'Waiting_to_start' if there is linked job") do
      MiqTask.where("id IN (SELECT miq_task_id FROM jobs)")
             .where(:state => "Queued").update_all(:state => "Waiting_to_start")
    end
  end
end
