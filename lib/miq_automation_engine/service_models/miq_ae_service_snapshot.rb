module MiqAeMethodService
  class MiqAeServiceSnapshot < MiqAeServiceModelBase
    expose :vm_or_template, :association => true
    expose :current?
    expose :get_current_snapshot

    def revert_to
      vm_or_template.revert_to_snapshot(id)
    end

    def remove
      vm_or_template.remove_snapshot(id)
    end
  end
end
