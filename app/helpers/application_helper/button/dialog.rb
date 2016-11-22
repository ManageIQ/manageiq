class ApplicationHelper::Button::Dialog < ApplicationHelper::Button::Basic
  needs :@edit

  def visible?
    @edit
  end

  private

  def nodes
    @view_context.x_node.split('_')
  end
end
