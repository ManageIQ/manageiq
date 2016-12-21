class ApplicationHelper::Button::VmVmrcConsole < ApplicationHelper::Button::VmConsole
  needs :@record

  def visible?
    console_supports_type?('VMRC')
  end

  def disabled?
    super { remote_control_supported? }
  end

  private

  def remote_control_supported?
    @record.validate_remote_console_vmrc_support
  rescue MiqException::RemoteConsoleNotSupportedError => err
    @error_message = _('VM VMRC Console error: %{error}') % {:error => err}
  end
end
