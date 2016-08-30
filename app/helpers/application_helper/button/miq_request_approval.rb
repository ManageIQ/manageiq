class ApplicationHelper::Button::MiqRequestApproval < ApplicationHelper::Button::MiqRequest
  needs_record
#something like needs_showtype
  def skip?
    return true if super
    return true if !role_allows?(:feature => "miq_request_approval") && ["miq_request_approve", "miq_request_deny"].include?(id)
    return true if ["approved", "denied"].include?(@record.approval_state) || @showtype == "miq_provisions"
  end
  delegate :role_allows?, :to => :@view_context
end
