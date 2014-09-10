module ConfigurationHelper::ConfigurationViewHelper
  def render_view_buttons(resource, view)
    (case resource
     when :compare, :drift
       view == "compressed" ? compare_or_drift_compressed(resource) : compare_or_drift_expanded(resource)
     when :compare_mode, :drift_mode
       view == "details" ? compare_or_drift_mode_details(resource) : compare_or_drift_mode_exists(resource)
     when :dashboards
       view == "textural" ? dashboards_textural : dashboards_graphical
     when :treesize
       view == "20" ?  treesize_small : treesize_large
     else
       case view
       when "grid" then grid_view(resource)
       when "tile" then tile_view(resource)
       else             list_view(resource)
       end
     end).html_safe
  end

  private

  def active_icon(image, text)
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/" + image,
                :border => "0",
                :alt    => text,
                :title  => text)
    end
  end

  def inactive_icon(image, text, resource, view)
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/" + image,
                        :border => "0",
                        :alt    => text),
              {:action   => "view_selected",
               :resource => resource,
               :view     => view},
              :remote => true,
              :title  => text)
    end
  end

  def compare_or_drift_compressed(resource)
    inactive_icon("view_expanded.png", "Expanded View", resource, "expanded") +
    active_icon("view_compressed.png", "Compressed View")
  end

  def compare_or_drift_expanded(resource)
    active_icon("view_expanded.png", "Expanded View") +
    inactive_icon("view_compressed.png", "Compressed View", resource, "compressed")
  end

  def compare_or_drift_mode_exists(resource)
    inactive_icon("view_list.png", "Details View", resource, "details") +
    active_icon("exists.png", "Exist Mode")
  end

  def compare_or_drift_mode_details(resource)
    active_icon("view_list.png", "Details Mode") +
    inactive_icon("exists.png", "Exists Mode", resource, "exists")
  end

  def dashboards_textural
    inactive_icon("view_graphical.png", "Graphical View", resource, "dashboards") +
    active_icon("view_textual.png", "Text View")
  end

  def dashboards_graphical
    active_icon("view_graphical.png", "Graphical View") +
    inactive_icon("view_textual.png", "Text View", :dashboards, "textural")
  end

  def treesize_small
    inactive_icon("tree-large.png", "Large Trees", :treesize, "32") +
    active_icon("tree-small.png", "Small Trees")
  end

  def treesize_large
    active_icon("tree-large.png", "Large Trees") +
    inactive_icon("tree-small.png", "Small Trees", :treesize, "20")
  end

  def grid_view(resource)
    [(active_icon("view_grid.png", "Grid View") if resource != :catalog),
     inactive_icon("view_tile.png", "Tile View", resource, "tile"),
     inactive_icon("view_list.png", "List View", resource, "list")].compact.join('')
  end

  def tile_view(resource)
    [(inactive_icon("view_grid.png", "Grid View", resource, "grid") if resource != :catalog),
     active_icon("view_tile.png", "Tile View"),
     inactive_icon("view_list.png", "List View", resource, "list")].compact.join('')
  end

  def list_view(resource)
    [(inactive_icon("view_grid.png", "Grid View", resource, "grid") if resource != :catalog),
     inactive_icon("view_tile.png", "Tile View", resource, "tile"),
     active_icon("view_list.png", "List View")].compact.join('')
  end
end
