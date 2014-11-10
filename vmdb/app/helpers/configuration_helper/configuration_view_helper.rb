module ConfigurationHelper
  module ConfigurationViewHelper
    def render_view_buttons(resource, view)
      (case resource
       when :compare, :drift
         view == "compressed" ? compare_or_drift_compressed(resource) : compare_or_drift_expanded(resource)
       when :compare_mode, :drift_mode
         view == "details" ? compare_or_drift_mode_details(resource) : compare_or_drift_mode_exists(resource)
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
      inactive_icon("view_expanded.png", _('Expanded View'), resource, "expanded") +
      active_icon("view_compressed.png", _('Compressed View'))
    end

    def compare_or_drift_expanded(resource)
      active_icon("view_expanded.png", _('Expanded View')) +
      inactive_icon("view_compressed.png", _('Compressed View'), resource, "compressed")
    end

    def compare_or_drift_mode_exists(resource)
      inactive_icon("view_list.png", _('Details View'), resource, "details") +
      active_icon("exists.png", _('Exist Mode'))
    end

    def compare_or_drift_mode_details(resource)
      active_icon("view_list.png", _('Details Mode')) +
      inactive_icon("exists.png", _('Exists Mode'), resource, "exists")
    end

    def treesize_small
      inactive_icon("tree-large.png", _('Large Trees'), :treesize, "32") +
      active_icon("tree-small.png", _('Small Trees'))
    end

    def treesize_large
      active_icon("tree-large.png", _('Large Trees')) +
      inactive_icon("tree-small.png", _('Small Trees'), :treesize, "20")
    end

    def grid_view(resource)
      [(active_icon("view_grid.png", _('Grid View')) if resource != :catalog),
       inactive_icon("view_tile.png", _('Tile View'), resource, "tile"),
       inactive_icon("view_list.png", _('List View'), resource, "list")].compact.join('')
    end

    def tile_view(resource)
      [(inactive_icon("view_grid.png", _('Grid View'), resource, "grid") if resource != :catalog),
       active_icon("view_tile.png", _('Tile View')),
       inactive_icon("view_list.png", _('List View'), resource, "list")].compact.join('')
    end

    def list_view(resource)
      [(inactive_icon("view_grid.png", _('Grid View'), resource, "grid") if resource != :catalog),
       inactive_icon("view_tile.png", _('Tile View'), resource, "tile"),
       active_icon("view_list.png", _('List View'))].compact.join('')
    end
  end
end
