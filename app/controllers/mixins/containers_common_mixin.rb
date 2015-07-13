module ContainersCommonMixin
  extend ActiveSupport::Concern

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])
    show_container(@record, controller_name, display_name)
  end

  private

  def show_container(record, controller_name, display_name)
    return if record_no_longer_exists?(record)

    @gtl_url = "/#{controller_name}/show/" << record.id.to_s << "?"
    drop_breadcrumb({:name => display_name,
                     :url  => "/#{controller_name}/show_list?page=#{@current_page}&refresh=y"},
                    true)
    if %w(download_pdf main summary_only).include? @display
      drop_breadcrumb(:name => "#{record.name} (Summary)",
                      :url  => "/#{controller_name}/show/#{record.id}")
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    elsif @display == "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @lastaction = "show_timeline"
      @timeline = @timeline_filter = true
      tl_build_timeline # Create the timeline report
      drop_breadcrumb(:name => "Timelines",
                      :url  => "/#{controller_name}/show/#{record.id}" \
                               "?refresh=n&display=timeline")
    elsif @display == "container_groups" || session[:display] == "container_groups" && params[:display].nil?
      show_container_display(record, "container_groups", ContainerGroup)
    elsif @display == "containers"
      show_container_display(record, "containers", Container, "container_group")
    elsif @display == "container_services" || session[:display] == "container_services" && params[:display].nil?
      show_container_display(record, "container_services", ContainerService)
    elsif @display == "container_routes" || session[:display] == "container_routes" && params[:display].nil?
      show_container_display(record, "container_routes", ContainerRoute)
    elsif @display == "container_replicators" || session[:display] == "container_replicators" && params[:display].nil?
      show_container_display(record, "container_replicators", ContainerReplicator)
    elsif @display == "container_projects" || session[:display] == "container_projects" && params[:display].nil?
      show_container_display(record, "container_projects", ContainerProject)
    end
    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def get_session_data
    @title      = ui_lookup(:tables => self.class.table_name)
    @layout     = self.class.table_name
    prefix      = self.class.session_key_prefix
    @lastaction = session["#{prefix}_lastaction".to_sym]
    @showtype   = session["#{prefix}_showtype".to_sym]
    @display    = session["#{prefix}_display".to_sym]
  end

  def set_session_data
    prefix                                 = self.class.session_key_prefix
    session["#{prefix}_lastaction".to_sym] = @lastaction
    session["#{prefix}_showtype".to_sym]   = @showtype
    session["#{prefix}_display".to_sym]    = @display unless @display.nil?
  end

  def show_container_display(record, display, clazz, alt_controller_name = nil)
    title = ui_lookup(:tables => display)
    drop_breadcrumb(:name => record.name + " (All #{title})",
                    :url  => "/#{alt_controller_name || controller_name}/show/#{record.id}?display=#{@display}")
    @view, @pages = get_view(clazz, :parent => record)  # Get the records (into a view) and the paginator
    @showtype = @display

    total_count = @view.extras.fetch(:total_count, 0)
    auth_count = @view.extras.fetch(:auth_count, 0)
    if total_count > auth_count
      @bottom_msg = "* You are not authorized to view " +
                    pluralize(total_count - auth_count, "other #{title.singularize}") +
                    " on this #{ui_lookup(:tables => @table_name)}"
    end
  end
end
