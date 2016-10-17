class ApplicationHelper::Button::InstanceMiqRequestNew < ApplicationHelper::Button::Basic
  def disabled?
    !provisioning_supported?
  end

  def calculate_properties
    super

    if disabled?
      self[:title] = N_('No Cloud Provider that supports instance provisioning added')
    end
  end

  private

  def provisioning_supported?
    EmsCloud.all.any? { |provider| provider.supports_provisioning? }
  end
end
