module EmsOperationsTaskMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def create_generic_task_queue(userid, ext_management_system, options = {})
      task_opts = {
        :action => "Creating #{table.name} for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => table.name,
        :method_name => "create_#{table.name.to_s.downcase}",
        :role        => 'ems_operations',
        :queue_name  => ext_management_system.queue_name_for_ems_operations,
        :zone        => ext_management_system.my_zone,
        :args        => [ext_management_system.id, options]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end

  def delete_generic_task_queue(userid)
    task_opts = {
      :action => "Deleting #{table.name} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => table.name,
      :method_name => "delete_#{table.name.to_s.downcase}",
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_generic_task_queue(options = {})
    task_opts = {
      :action => "updating #{table.name} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => table.name,
      :method_name => "update_#{table.name.to_s.downcase}",
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
