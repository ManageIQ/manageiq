class ApplicationHelper::Button::InstanceDisassociateFloatingIp < ApplicationHelper::Button::Basic
  def disabled?
    if !@record.supports_disassociate_floating_ip?
      @error_message = @record.unsupported_reason(:disassociate_floating_ip)
    elsif @record.number_of(:floating_ips).zero?
      @error_message = _("Instance \"%{name}\" does not have any associated Floating IPs") % { :name => @record.name }
    end
    @error_message.present?
  end
end
