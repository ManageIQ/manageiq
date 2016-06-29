class ApplicationHelper::Button::VmPublish < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:publish) || @is_redhat
  end
end
