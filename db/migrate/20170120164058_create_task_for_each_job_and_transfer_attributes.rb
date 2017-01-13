class CreateTaskForEachJobAndTransferAttributes < ActiveRecord::Migration[5.0]
  class Job < ActiveRecord::Base
    belongs_to :miq_task, :class_name =>'CreateTaskForEachJobAndTransferAttributes::MiqTask'
    self.inheritance_column = :_type_disabled
  end

  class MiqTask < ActiveRecord::Base
    has_one :job, :class_name => 'CreateTaskForEachJobAndTransferAttributes::Job'
  end

  def up
    say_with_time("Creating tasks associated with jobs") do
      Job.find_each do |job|
        job.create_miq_task(:status        => job.status.try(:capitalize),
                            :name          => job.name,
                            :message       => job.message,
                            :state         => job.state.try(:capitalize),
                            :userid        => job.userid,
                            :miq_server_id => job.miq_server_id,
                            :context_data  => job.context,
                            :started_on    => job.started_on,
                            :zone          => job.zone)
      end
    end
  end

  def down
    say_with_time("Deleting all tasks which have job") do
      Job.find_each do |job|
        job.miq_task.delete
        job.update_attributes(:miq_task_id => nil)
      end
    end
  end
end
