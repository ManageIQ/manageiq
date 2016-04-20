module ConfigurationHelper
  module ConfigurationViewHelper
    def render_view_buttons(resource, view)
      (case resource
       when :compare, :drift
         view == "compressed" ? compare_or_drift_compressed(resource) : compare_or_drift_expanded(resource)
       when :compare_mode, :drift_mode
         view == "details" ? compare_or_drift_mode_details(resource) : compare_or_drift_mode_exists(resource)
       when :treesize
         view == "20" ? treesize_small : treesize_large
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
        content_tag(:i, nil, :class => image, :title => text)
      end
    end

    def inactive_icon(image, text, resource, view)
      content_tag(:li) do
        link_to(content_tag(:i, nil, :class => image,
                                     :alt   => text),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => view},
                :remote       => true,
                'data-method' => :post,
                :title        => text)
      end
    end

    def compare_or_drift_compressed(resource)
      inactive_icon("product product-view_expanded", _('Expanded View'), resource, "expanded") +
        active_icon("fa fa-bars fa-rotate-90", _('Compressed View'))
    end

    def compare_or_drift_expanded(resource)
      active_icon("product product-view_expanded", _('Expanded View')) +
        inactive_icon("fa fa-bars fa-rotate-90", _('Compressed View'), resource, "compressed")
    end

    def compare_or_drift_mode_exists(resource)
      inactive_icon("fa fa-bars fa-rotate-90", _('Details Mode'), resource, "details") +
        active_icon("product product-exists", _('Exists Mode'))
    end

    def compare_or_drift_mode_details(resource)
      active_icon("fa fa-bars fa-rotate-90", _('Details Mode')) +
        inactive_icon("product product-exists", _('Exists Mode'), resource, "exists")
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
      [(active_icon("fa fa-th", _('Grid View')) if resource != :catalog),
       inactive_icon("fa fa-th-large", _('Tile View'), resource, "tile"),
       inactive_icon("fa fa-th-list", _('List View'), resource, "list")].compact.join('')
    end

    def tile_view(resource)
      [(inactive_icon("fa fa-th", _('Grid View'), resource, "grid") if resource != :catalog),
       active_icon("fa fa-th-large", _('Tile View')),
       inactive_icon("fa fa-th-list", _('List View'), resource, "list")].compact.join('')
    end

    def list_view(resource)
      [(inactive_icon("fa fa-th", _('Grid View'), resource, "grid") if resource != :catalog),
       inactive_icon("fa fa-th-large", _('Tile View'), resource, "tile"),
       active_icon("fa fa-th-list", _('List View'))].compact.join('')
    end

    def has_any_role?(arr)
      arr.any? { |r| role_allows(:feature => r) }
    end
  end
end
