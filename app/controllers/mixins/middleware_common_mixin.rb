module MiddlewareCommonMixin
  extend ActiveSupport::Concern
  include MiddlewareOperationsMixin

  def show
    return unless init_show
    @ems = @record
    clear_topology_breadcrumb

    show_middleware
  end

  private

  def display_name(display = nil)
    if display.blank?
      ui_lookup(:tables => @record.class.base_class.name)
    else
      ui_lookup(:tables => display)
    end
  end

  def listicon_image(item, _view)
    item.decorate.try(:listicon_image)
  end

  def clear_topology_breadcrumb
    # fix breadcrumbs - remove displaying 'topology' in breadcrumb when navigating to a middleware related entity summary page
    if @breadcrumbs.present? && (@breadcrumbs.last[:name].eql? 'Topology')
      @breadcrumbs.clear
    end
  end

  def show_middleware
    drop_breadcrumb({:name => display_name,
                     :url  => show_list_link(@record, :page => @current_page, :refresh => 'y')
                    }, true)
    case @display
    when 'main'                          then show_main
    when 'download_pdf', 'summary_only'  then show_download
    when 'timeline'                      then show_timeline
    when 'performance'                   then show_performance
    end
  end

  def show_middleware_entities(klass)
    @showtype = @display = params[:display] unless params[:display].nil?
    breadcrumb_title = _("%{name} (All %{title})") % {:name  => @record.name,
                                                      :title => display_name(@display)}
    drop_breadcrumb(:name => breadcrumb_title, :url => show_link(@record, :display => @display))
    @view, @pages = get_view(klass, :parent => @record)
  end
end
