class ApplicationHelper::Button::MiqRequest < ApplicationHelper::Button::GenericFeatureButton
  needs :@record

  def visible?
    return false if @record.resource_type == "AutomationRequest" &&
                   !%w(miq_request_approve miq_request_deny miq_request_delete).include?(@feature)
    true
  end
end
