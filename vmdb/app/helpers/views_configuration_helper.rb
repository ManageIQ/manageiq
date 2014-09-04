module ViewsConfigurationHelper

  def choose_view(resource, view)
    @out = ""
    if resource == :compare || resource == :drift
      compare_or_drift(resource, view)
    elsif resource == :compare_mode || resource == :drift_mode
      compare_or_drift_mode(resource, view)
    elsif resource == :dashboards
      dashboards(view)
    elsif resource == :treesize
      treesize(view)
    else
      other_views(resource, view)
    end
    @out.html_safe
  end

  def compare_or_drift(resource, view)
    if view == "compressed"
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_expanded.png",
                          :border => "0",
                          :alt    => "Expanded View",),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "expanded"},
                :remote => true,
                :title  => "Expanded View")
      end
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/view_compressed.png",
                  :border => "0",
                  :alt    => "Compressed View",
                  :title  => "Compressed View")
      end
    else
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/view_expanded.png",
                  :border => "0",
                  :alt    => "Expanded View",
                  :title  => "Expanded View")
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_compressed.png",
                          :border => "0",
                          :alt    => "Compressed View",),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "compressed"},
                :remote => true,
                :title  => "Compressed View")
      end
    end
  end

  def compare_or_drift_mode(resource, view)
    if view == "exists"
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_list.png",
                          :border => "0",
                          :alt    => "Details View"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "details"},
                :remote => true,
                :title  => "Details Mode")
      end
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/exists.png",
                  :border => "0",
                  :alt    => "Exists Mode",
                  :title  => "Exists Mode")
      end
    else
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/view_list.png",
                  :border => "0",
                  :alt    => "Details Mode",
                  :title  => "Details Mode")
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/exists.png",
                          :border => "0",
                          :alt    => "Exists Mode"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "exists"},
                :remote => true,
                :title  => "Exists Mode")
      end
    end
  end

  def dashboards(view)
    if view == "textural"
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_graphical.png",
                          :border => "0",
                          :alt    => "Graphical View"),
                {:action   => "view_selected",
                 :resource => :dashboards,
                 :view     => "graphical"},
                :remote => true,
                :title  => "Graphical View")
      end
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/view_textual.png",
                  :border => "0",
                  :alt    => "Text View",
                  :title  => "Text View")
      end
    else
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/view_graphical.png",
                  :border => "0",
                  :alt    => "Graphical View",
                  :title  => "Graphical View")
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_textual.png",
                          :border => "0",
                          :alt    => "Text View"),
                {:action   => "view_selected",
                 :resource => :dashboards,
                 :view     => "textural"},
                :remote => true,
                :title  => "Text View")
      end
    end
  end

  def treesize(view)
    if view == "20"
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/tree-large.png",
                          :border => "0",
                          :alt    => "Large Trees"),
                {:action   => "view_selected",
                 :resource => :treesize,
                 :view     => "32"},
                :remote => true,
                :title  => "Large Trees")
      end
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/tree-small.png",
                  :border => "0",
                  :alt    => "Small Trees",
                  :title  => "Small Trees")
      end
    else
      @out << content_tag(:li, class: "active") do
        image_tag("/images/toolbars/tree-large.png",
                  :border => "0",
                  :alt    => "Large Trees",
                  :title  => "Latge Trees")
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/tree-small.png",
                          :border => "0",
                          :alt    => "Small Trees"),
                {:action   => "view_selected",
                 :resource => :treesize,
                 :view     => "20"},
                :remote => true,
                :title  => "Small Trees")
      end
    end
  end

  def other_views(resource, view)
    if view == "grid"
      if resource != :catalog
        @out << content_tag(:li, class: "active") do
          image_tag("/images/toolbars/view_grid.png",
                    :border => "0",
                    :alt    => "Grid View",
                    :title  => "Grid View")
        end
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_tile.png",
                          :border => "0",
                          :alt    =>"Tile View"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "tile"},
                :remote => true,
                :title  => "Tile View")
      end
      @out << content_tag(:li) do
        link_to(image_tag("/images/toolbars/view_list.png",
                          :border => "0",
                          :alt    => "List View"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "list"},
                :remote => true,
                :title  => "List View")
      end
    elsif view == "tile"
      if resource != :catalog
        @out << content_tag("li") do
          link_to(image_tag("/images/toolbars/view_grid.png",
                            :border => "0",
                            :alt    => "Grid View"),
                 {:action   => "view_selected",
                  :resource => resource,
                  :view     => "grid"},
                 :remote => true,
                 :title  => "Grid View")
        end
      end
      @out << content_tag("li", class: "active") do
        image_tag("/images/toolbars/view_tile.png",
                          :border => "0",
                          :alt    => "Tile View",
                          :title  => "Tile View")
      end
      @out << content_tag("li") do
        link_to(image_tag("/images/toolbars/view_list.png",
                          :border => "0",
                          :alt    => "List View"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "list"},
                :remote => true,
                :title  => "List View")
      end
    else
      if resource != :catalog
        @out << content_tag("li") do
          link_to(image_tag("/images/toolbars/view_grid.png",
                            :border => "0",
                            :alt    => "Grid View"),
                 {:action   => "view_selected",
                  :resource => resource,
                  :view     => "grid"},
                 :remote => true,
                 :title  => "Grid View")
        end
      end
      @out << content_tag("li") do
        link_to(image_tag("/images/toolbars/view_tile.png",
                          :border => "0",
                          :alt    =>"Tile View"),
                {:action   => "view_selected",
                 :resource => resource,
                 :view     => "tile"},
                :remote => true,
                :title  => "Tile View")
      end
      @out << content_tag("li", class: "active") do
        image_tag("/images/toolbars/view_list.png",
                  :border => "0",
                  :alt    => "List View",
                  :title=>"List View")
      end
    end
  end
end
