module MiqAeServiceEmsOperationsMixin
  extend ActiveSupport::Concern

  # Instance Methods
  def sync_or_async_ems_operation(sync, method_name, args)
    ar_method do
      queue_options = {
        :class_name  => @object.class.name,
        :instance_id => @object.id,
        :method_name => method_name,
        :args        => args,
        :zone        => @object.my_zone,
        :role        => "ems_operations",
        :task_id     => nil               # Clear task_id to allow running synchronously under current worker process
      }

      if sync
        task_options = {:name => method_name.titleize, :userid => "system"}
        task_id = MiqTask.generic_action_with_callback(task_options, queue_options)
        MiqTask.wait_for_taskid(task_id)
      else
        MiqQueue.put(queue_options)
      end
    end
    true
  end
end
