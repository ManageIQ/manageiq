module EmsOperationsTaskMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def create_generic_task_queue(klass, userid, ext_management_system, method_name, options = {})
      task_opts = {
        :action => "Creating #{klass.name} for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => klass.name,
        :method_name => method_name,
        :role        => 'ems_operations',
        :queue_name  => ext_management_system.queue_name_for_ems_operations,
        :zone        => ext_management_system.my_zone,
        :args        => [ext_management_system.id, options]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end

  def delete_generic_task_queue(klass, userid, method_name)
    task_opts = {
      :action => "Deleting #{klass.name} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => klass.name,
      :method_name => method_name,
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_generic_task_queue(klass, method_name, options = {})
    task_opts = {
      :action => "updating #{klass.name} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => klass.name,
      :method_name => method_name,
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
