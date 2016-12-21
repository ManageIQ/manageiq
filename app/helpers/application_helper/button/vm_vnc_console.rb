class ApplicationHelper::Button::VmVncConsole < ApplicationHelper::Button::VmConsole
  needs :@record

  def visible?
    return console_supports_type?('VNC') if @record.vendor == 'vmware'
    @record.console_supported?('vnc')
  end

  def disabled?
    @error_message = _('The web-based VNC console is not available because the VM is not powered on') unless on?
    @error_message.present?
  end
end
