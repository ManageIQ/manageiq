class ApplicationHelper::Button::VmRetire < ApplicationHelper::Button::Basic
  def skip?
    !@record.supports_retire?
  end

  def disabled?
    false
  end
end
