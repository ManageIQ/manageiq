class ApplicationHelper::Button::VmRetire < ApplicationHelper::Button::Basic
  needs_record

  def visible?
    @record.supports_retire?
  end

  def disabled?
    false
  end
end
