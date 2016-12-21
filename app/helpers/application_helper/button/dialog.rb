class ApplicationHelper::Button::Dialog < ApplicationHelper::Button::ButtonWithoutRbacCheck
  needs :@edit

  def visible?
    @edit
  end

  private

  def nodes
    @view_context.x_node.split('_')
  end
end
