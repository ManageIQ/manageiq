module ConfigurationHelper::ConfigurationViewHelper
  def choose_view(resource, view)
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

  def compare_or_drift_compressed(resource)
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/view_expanded.png",
                        :border => "0",
                        :alt    => t = "Expanded View"),
              {:action   => "view_selected",
               :resource => resource,
               :view     => "expanded"},
              :remote => true,
              :title  => t)
    end +
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/view_compressed.png",
                :border => "0",
                :alt    => t = "Compressed View",
                :title  => t)
    end
  end

  def compare_or_drift_expanded(resource)
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/view_expanded.png",
                :border => "0",
                :alt    => t = "Expanded View",
                :title  => t)
    end +
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/view_compressed.png",
                        :border => "0",
                        :alt    => t = "Compressed View"),
              {:action   => "view_selected",
               :resource => resource,
               :view     => "compressed"},
              :remote => true,
              :title  => t)
    end
  end

  def compare_or_drift_mode_exists(resource)
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/view_list.png",
                        :border => "0",
                        :alt    => t = "Details View"),
              {:action   => "view_selected",
               :resource => resource,
               :view     => "details"},
              :remote => true,
              :title  => t)
    end +
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/exists.png",
                :border => "0",
                :alt    => t = "Exists Mode",
                :title  => t)
    end
  end

  def compare_or_drift_mode_details(resource)
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/view_list.png",
                :border => "0",
                :alt    => t = "Details Mode",
                :title  => t)
    end +
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/exists.png",
                        :border => "0",
                        :alt    => t = "Exists Mode"),
              {:action   => "view_selected",
               :resource => resource,
               :view     => "exists"},
              :remote => true,
              :title  => t)
    end
  end

  def dashboards_textural
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/view_graphical.png",
                        :border => "0",
                        :alt    => t = "Graphical View"),
              {:action   => "view_selected",
               :resource => :dashboards,
               :view     => "graphical"},
              :remote => true,
              :title  => t)
    end +
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/view_textual.png",
                :border => "0",
                :alt    => t = "Text View",
                :title  => t)
    end
  end

  def dashboards_graphical
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/view_graphical.png",
                :border => "0",
                :alt    => t = "Graphical View",
                :title  => t)
    end +
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/view_textual.png",
                        :border => "0",
                        :alt    => t = "Text View"),
              {:action   => "view_selected",
               :resource => :dashboards,
               :view     => "textural"},
              :remote => true,
              :title  => t)
    end
  end

  def treesize_small
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/tree-large.png",
                        :border => "0",
                        :alt    => t = "Large Trees"),
              {:action   => "view_selected",
               :resource => :treesize,
               :view     => "32"},
              :remote => true,
              :title  => t)
    end +
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/tree-small.png",
                :border => "0",
                :alt    => t = "Small Trees",
                :title  => t)
    end
  end

  def treesize_large
    content_tag(:li, :class => "active") do
      image_tag("/images/toolbars/tree-large.png",
                :border => "0",
                :alt    => t = "Large Trees",
                :title  => t)
    end +
    content_tag(:li) do
      link_to(image_tag("/images/toolbars/tree-small.png",
                        :border => "0",
                        :alt    => t = "Small Trees"),
              {:action   => "view_selected",
               :resource => :treesize,
               :view     => "20"},
              :remote => true,
              :title  => t)
    end
  end

  def grid_view(resource)
    [if resource != :catalog
       content_tag(:li, :class => "active") do
         image_tag("/images/toolbars/view_grid.png",
                   :border => "0",
                   :alt    => t = "Grid View",
                   :title  => t)
       end
     end,
     content_tag(:li) do
       link_to(image_tag("/images/toolbars/view_tile.png",
                         :border => "0",
                         :alt    => t = "Tile View"),
               {:action   => "view_selected",
                :resource => resource,
                :view     => "tile"},
               :remote => true,
               :title  => t)
     end,
     content_tag(:li) do
       link_to(image_tag("/images/toolbars/view_list.png",
                         :border => "0",
                         :alt    => t = "List View"),
               {:action   => "view_selected",
                :resource => resource,
                :view     => "list"},
               :remote => true,
               :title  => t)
     end].compact.join('')
  end

  def tile_view(resource)
    [if resource != :catalog
       content_tag("li") do
         link_to(image_tag("/images/toolbars/view_grid.png",
                           :border => "0",
                           :alt    => t = "Grid View"),
                 {:action   => "view_selected",
                  :resource => resource,
                  :view     => "grid"},
                 :remote => true,
                 :title  => t)
       end
     end,
     content_tag(:li, :class => "active") do
       image_tag("/images/toolbars/view_tile.png",
                 :border => "0",
                 :alt    => t = "Tile View",
                 :title  => t)
     end,
     content_tag("li") do
       link_to(image_tag("/images/toolbars/view_list.png",
                         :border => "0",
                         :alt    => t = "List View"),
               {:action   => "view_selected",
                :resource => resource,
                :view     => "list"},
               :remote => true,
               :title  => t)
     end].compact.join('')
  end

  def list_view(resource)
    [if resource != :catalog
       content_tag("li") do
         link_to(image_tag("/images/toolbars/view_grid.png",
                           :border => "0",
                           :alt    => t = "Grid View"),
                 {:action   => "view_selected",
                  :resource => resource,
                  :view     => "grid"},
                 :remote => true,
                 :title  => t)
       end
     end,
     content_tag("li") do
       link_to(image_tag("/images/toolbars/view_tile.png",
                         :border => "0",
                         :alt    => t = "Tile View"),
               {:action   => "view_selected",
                :resource => resource,
                :view     => "tile"},
               :remote => true,
               :title  => t)
     end,
     content_tag(:li, :class => "active") do
       image_tag("/images/toolbars/view_list.png",
                 :border => "0",
                 :alt    => t = "List View",
                 :title  => t)
     end].compact.join('')
  end
end
