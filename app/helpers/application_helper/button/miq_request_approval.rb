class ApplicationHelper::Button::MiqRequestApproval < ApplicationHelper::Button::MiqRequest
  needs :@miq_request, :@showtype, :@record

  def visible?
    return false unless super
    return false if !role_allows?(:feature => "miq_request_approval") && ["miq_request_approve", "miq_request_deny"].include?(id)
    return false if ["approved", "denied"].include?(@record.approval_state) || @showtype == "miq_provisions"
    true
  end
  delegate :role_allows?, :to => :@view_context
end
