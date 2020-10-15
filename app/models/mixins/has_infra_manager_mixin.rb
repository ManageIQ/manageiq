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
    infra_manager ||= propagate_child_attributes(build_infra_manager(:name => "#{name} Virtualization Manager"))
  end
end
