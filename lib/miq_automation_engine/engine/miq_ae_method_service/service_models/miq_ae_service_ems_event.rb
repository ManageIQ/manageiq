module MiqAeMethodService
  class MiqAeServiceEmsEvent < MiqAeServiceEventStream
    def refresh(*targets, sync)
      ar_method { @object.refresh(*targets, sync) } unless targets.blank?
    end

    def refresh_new_target
      ar_method { @object.refresh_new_target }
    end

    def policy(target_str, policy_event, param)
      ar_method { @object.policy(target_str, policy_event, param) }
    end

    def scan(*targets)
      ar_method { @object.scan(*targets) } unless targets.blank?
    end

    def src_vm_as_template(flag)
      ar_method { @object.src_vm_as_template(flag) }
    end

    def change_event_target_state(target, param)
      ar_method { @object.change_event_target_state(target, param) }
    end

    def src_vm_destroy_all_snapshots
      ar_method { @object.src_vm_destroy_all_snapshots }
    end

    def src_vm_disconnect_storage
      ar_method { @object.src_vm_disconnect_storage }
    end
  end
end
