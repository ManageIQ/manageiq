class ApplicationHelper::Button::MiqAeDomain < ApplicationHelper::Button::MiqAe
  needs :@record

  def disabled?
    !editable?
  end

  private

  def editable?
    @record.editable_properties?
  end
end
