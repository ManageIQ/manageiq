class ApplicationHelper::Button::BasicImage < ApplicationHelper::Button::Basic
  def skip?
    @sb.fetch_path(:trees, :vandt_tree, :active_node).present? && (
      @sb[:trees][:vandt_tree][:active_node] == "xx-arch" ||
      @sb[:trees][:vandt_tree][:active_node] == "xx-orph")
  end
end
