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
      build_infra_manager(:parent_manager  => self,
                          :name            => "#{name} Virtualization Manager",
                          :zone_id         => zone_id,
                          :provider_region => provider_region)
    end

    infra_manager
  end
end
