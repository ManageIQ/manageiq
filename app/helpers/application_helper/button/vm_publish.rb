class ApplicationHelper::Button::VmPublish < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:publish) || @is_redhat
  end
end
