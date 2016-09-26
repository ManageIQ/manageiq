class ApplicationHelper::Button::MiqRequestApproval < ApplicationHelper::Button::MiqRequest
  needs :@showtype, :@record

  def role_allows_feature?
    role_allows?(:feature => "miq_request_approval")
  end

  def visible?
    return false unless super
    return false if %w(approved denied).include?(@record.approval_state) || @showtype == "miq_provisions"
    true
  end
end
