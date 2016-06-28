class ApplicationHelper::Button::InstanceDisassociateFloatingIp < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if !@record.is_available?(:disassociate_floating_ip)
      self[:title] = @record.is_available_now_error_message(:disassociate_floating_ip)
    elsif @record.number_of(:floating_ips) == 0
      self[:title] = _("%{instance} \"%{name}\" does not have any associated %{floating_ips}") % {
        :instance     => ui_lookup(:table => 'vm_cloud'),
        :name         => @record.name,
        :floating_ips => ui_lookup(:tables => 'floating_ip')
      }
    end
  end

  def disabled?
    !@record.is_available?(:disassociate_floating_ip) || @record.number_of(:floating_ips) == 0
  end
end
