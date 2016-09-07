class ApplicationHelper::Button::BasicImage < ApplicationHelper::Button::Basic
  def visible?
    @sb.fetch_path(:trees, :vandt_tree, :active_node).blank? ||
      (@sb[:trees][:vandt_tree][:active_node] != "xx-arch" &&
       @sb[:trees][:vandt_tree][:active_node] != "xx-orph")
  end
end
