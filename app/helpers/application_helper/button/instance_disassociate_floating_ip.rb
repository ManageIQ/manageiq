class ApplicationHelper::Button::InstanceDisassociateFloatingIp < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if !@record.supports_disassociate_floating_ip?
      self[:title] = @record.unsupported_reason(:disassociate_floating_ip)
    elsif @record.number_of(:floating_ips).zero?
      self[:title] = _("Instance \"%{name}\" does not have any associated Floating IPs") % {
        :name => @record.name,
      }
    end
  end

  def disabled?
    !@record.supports_disassociate_floating_ip? || @record.number_of(:floating_ips).zero?
  end
end
