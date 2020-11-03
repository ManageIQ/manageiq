module HasInfraManagerMixin
  extend ActiveSupport::Concern

  def virtualization_endpoint_created(role)
    if role == "kubevirt" && infra_manager.nil?
      infra_manager = ensure_infra_manager
      infra_manager.save
    end
  end

  def virtualization_endpoint_destroyed(role)
    if role == "kubevirt" && infra_manager.present?
      infra_manager.destroy_queue
    end
  end

  private

  def ensure_infra_manager
    if infra_manager.nil?
      build_infra_manager

      # TODO: move this out of here and into ensure managers
      propagate_child_manager_attributes(infra_manager, "#{name} Virtualization Manager")
    end

    infra_manager
  end
end
