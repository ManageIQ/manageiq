class ApplicationHelper::Button::InstanceEvacuate < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:evacuate)
  end
end
