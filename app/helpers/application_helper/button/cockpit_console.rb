class ApplicationHelper::Button::CockpitConsole < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    record_type = @record.respond_to?(:current_state) ? _('VM') : _('Container Node')
    @error_message = _("The web-based console is not available because the %{record_type} is not powered on" % {:record_type => record_type}) unless on?
    @error_message = _('The web-based console is not available because the Windows platform is not supported') unless platform_supported?
    @error_message.present?
  end

  private

  def on?
    return @record.current_state == 'on' if @record.respond_to?(:current_state) # VM status
    @record.ready_condition_status == 'True' if @record.respond_to?(:ready_condition_status) # Container status
  end

  def platform_supported?
    @record.respond_to?(:current_state) && @record.platform.downcase != 'windows'
  end
end
