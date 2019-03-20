module ManageIQ::Providers::EmbeddedAnsible
  include_concern :Seeding

  def self.queue(klass, zone, instance_id, method_name, args, action, auth_user)
    task_opts = {
      :action => action,
      :userid => auth_user || "system"
    }

    queue_opts = {
      :args        => args,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :class_name  => klass.name,
      :method_name => method_name,
      :role        => "embedded_ansible",
      :zone        => zone
    }
    queue_opts[:instance_id] = instance_id if instance_id
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.notify(klass, op_type, manager_id, params, success)
    op_arg = params.except(:name, :manager_ref).collect { |k, v| "#{k}=#{v}" }.join(', ')
    _log.info("#{klass.name} in provider #{op_type} with parameters: #{op_arg} #{success ? 'succeeded' : 'failed'}")
    Notification.create(
      :type    => success ? :tower_op_success : :tower_op_failure,
      :options => {
        :op_name => "#{klass::FRIENDLY_NAME} #{op_type}",
        :op_arg  => "(#{op_arg})",
        :tower   => "EMS(manager_id=#{manager_id})"
      }
    )
  end
end
