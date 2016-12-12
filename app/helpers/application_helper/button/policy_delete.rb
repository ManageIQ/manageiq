class ApplicationHelper::Button::PolicyDelete < ApplicationHelper::Button::PolicyButton
  def disabled?
    @error_message = _('Policies that belong to Profiles can not be deleted') unless @policy.memberof.empty?
    @error_message.present?
  end
end
