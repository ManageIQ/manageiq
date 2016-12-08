class ApplicationHelper::Button::TemplateProvision < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('Selected item is not eligible for Provisioning') unless @record.supports_provisioning?
    @error_message.present?
  end
end
