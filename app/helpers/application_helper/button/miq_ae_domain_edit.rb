class ApplicationHelper::Button::MiqAeDomainEdit < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    @error_message = _('Read Only Domain cannot be edited') if super
    @error_message.present?
  end

  def visible?
    super || @record.editable_properties?
  end
end
