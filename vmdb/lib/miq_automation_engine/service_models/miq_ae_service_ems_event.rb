module MiqAeMethodService
  class MiqAeServiceEmsEvent < MiqAeServiceModelBase
    expose :ext_management_system, :association => true
    expose :ems,                   :association => true, :method => :ext_management_system
    expose :src_vm,                :association => true, :method => :src_vm_or_template
    expose :vm,                    :association => true, :method => :src_vm_or_template
    expose :src_host,              :association => true
    expose :host,                  :association => true, :method => :src_host
    expose :dest_vm,               :association => true, :method => :dest_vm_or_template
    expose :dest_host,             :association => true
    expose :service,               :association => true

    def refresh(*targets)
      ar_method { @object.refresh(*targets) } unless targets.blank?
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

    def src_vm_refresh_on_reconfig
      ar_method { @object.src_vm_refresh_on_reconfig }
    end
  end
end
