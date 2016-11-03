class ApplicationHelper::Button::MiqAeNamespaceEdit < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    @error_message = N_('Domain is Locked.') if super
    @error_message.present?
  end

  def visible?
    super || editable_domain?(@record)
  end
end
