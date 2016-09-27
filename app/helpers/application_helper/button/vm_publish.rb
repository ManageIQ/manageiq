class ApplicationHelper::Button::VmPublish < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.is_available?(:publish) && !@is_redhat
  end
end
