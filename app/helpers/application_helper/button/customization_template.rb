class ApplicationHelper::Button::CustomizationTemplate < ApplicationHelper::Button::Basic
  def visible?
    !root? && !system?
  end

  private

  def root?
    @view_context.nodes.first == 'root'
  end

  def system?
    @view_context.nodes.last == 'system' || @record.try(:system)
  end
end
