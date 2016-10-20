class ApplicationHelper::Button::MiqAeNamespaceEdit < ApplicationHelper::Button::MiqAeDomainLock
  needs :@record

  def visible?
    super || editable_domain?(@record)
  end
end
