class ApplicationHelper::Button::MiqAeDomain < ApplicationHelper::Button::MiqAe
  needs :@record

  def disabled?
    !@record.editable_properties?
  end
end
