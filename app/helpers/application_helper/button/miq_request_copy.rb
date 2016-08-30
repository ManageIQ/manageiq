class ApplicationHelper::Button::MiqRequestCopy < ApplicationHelper::Button::MiqRequest
  needs_record
#something like needs_showtype
  def skip?
    return true if super
    resource_types_for_miq_request_copy = %w(MiqProvisionRequest
                                             MiqHostProvisionRequest
                                             MiqProvisionConfiguredSystemRequest)
    return true if !resource_types_for_miq_request_copy.include?(@record.resource_type) ||
                   ((current_user.name != @record.requester_name ||
                     !@record.request_pending_approval?) &&
                    @showtype == "miq_provisions")
  end
  delegate :current_user, :to => :@view_context
end
