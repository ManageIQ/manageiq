class ApplicationHelper::Button::VmMiqRequestNew < ApplicationHelper::Button::Basic
  def disabled?
    !provisioning_supported?
  end

  def calculate_properties
    super

    if disabled?
      self[:title] = N_('No Infrastructure Provider that supports VM provisioning added')
    end
  end

  private

  def provisioning_supported?
    EmsInfra.all.any? { |provider| provider.supports_provisioning? }
  end
end
