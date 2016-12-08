class ApplicationHelper::Button::MiqAeNamespaceEdit < ApplicationHelper::Button::MiqAeDomain
  needs :@record

  def disabled?
    @error_message = _('Domain is Locked.') unless editable?
    @error_message.present?
  end

  def visible?
    super || editable_domain?(@record)
  end

  private

  def editable?
    return @record.editable? if @record.instance_of?(MiqAeNamespace)
    super
  end
end
