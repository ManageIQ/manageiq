class ApplicationHelper::Button::InstanceAssociateFloatingIp < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if !@record.supports_associate_floating_ip?
      self[:title] = @record.unsupported_reason(:associate_floating_ip)
    elsif @record.cloud_tenant.nil? || @record.cloud_tenant.floating_ips.empty?
      self[:title] = _("There are no Floating IPs available to this Instance.")
    end
  end

  def disabled?
    !@record.supports_associate_floating_ip? ||
      (@record.cloud_tenant.nil? || @record.cloud_tenant.floating_ips.empty?)
  end
end
