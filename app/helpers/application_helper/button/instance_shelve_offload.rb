class ApplicationHelper::Button::InstanceShelveOffload < ApplicationHelper::Button::Basic
  needs_record

  def skip?
    !@record.is_available?(:shelve_offload)
  end
end
