class ApplicationHelper::Button::MiqRequest < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    return false if @record.resource_type == "AutomationRequest" &&
                   !["miq_request_approve", "miq_request_deny", "miq_request_delete"].include?(id)
    true
  end
end
