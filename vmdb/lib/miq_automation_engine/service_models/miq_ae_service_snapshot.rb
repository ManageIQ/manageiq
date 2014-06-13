module MiqAeMethodService
  class MiqAeServiceSnapshot < MiqAeServiceModelBase
    expose :vm, :association => true
    expose :current?
    expose :get_current_snapshot

    def revert_to
      self.vm.revert_to_snapshot(self.id)
    end

    def remove
      self.vm.remove_snapshot(self.id)
    end
  end
end
