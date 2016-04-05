module ContainersCommonMixin
  extend ActiveSupport::Concern
  include AuthorizationMessagesMixin

  def index
    redirect_to :action => 'show_list'
  end

  def show
    # fix breadcrumbs - remove displaying 'topology' when navigating to any container related entity summary page
    if @breadcrumbs.present? && (@breadcrumbs.last[:name].eql? 'Topology')
      @breadcrumbs.clear
    end
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])
    show_container(@record, controller_name, display_name)
  end

  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    params[:display] = @display if ["#{params[:controller]}s"].include?(@display)  # displaying container_*
    params[:page] = @current_page if @current_page.nil?   # Save current page for list refresh

    # Handle Toolbar Policy Tag Button
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    tag(self.class.model) if params[:pressed] == "#{params[:controller]}_tag"
    return if ["#{params[:controller]}_tag"].include?(params[:pressed]) && @flash_array.nil? # Tag screen showing

    # Handle scan
    if params[:pressed] == "container_image_scan"
      scan_images

      render :update do |page|
        if @lastaction == "show"
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        else
          page.replace_html("main_div", :partial => "layouts/gtl")
        end
      end
    end
  end

  def show_list
    process_show_list
  end

  private

  def display_name
    ui_lookup(:tables => @record.class.base_class.name)
  end

  def show_container(record, controller_name, display_name)
    return if record_no_longer_exists?(record)

    @gtl_url = "/show"
    drop_breadcrumb({:name => display_name,
                     :url  => "/#{controller_name}/show_list?page=#{@current_page}&refresh=y"},
                    true)
    if %w(download_pdf main summary_only).include? @display
      get_tagdata(@record)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => record.name},
                      :url  => "/#{controller_name}/show/#{record.id}")
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    elsif @display == "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @lastaction = "show_timeline"
      @timeline = @timeline_filter = true
      tl_build_timeline # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"),
                      :url  => "/#{controller_name}/show/#{record.id}" \
                               "?refresh=n&display=timeline")
    elsif @display == "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => record.name},
                      :url  => "/#{controller_name}/show/#{record.id}" \
                               "?display=#{@display}&refresh=n")
      perf_gen_init_options # Intialize options, charts are generated async
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
    elsif @display == "container_images" || session[:display] == "container_images" && params[:display].nil?
      show_container_display(record, "container_images", ContainerImage)
    elsif @display == "container_image_registries" ||
          session[:display] == "container_image_registries" &&
          params[:display].nil?
      show_container_display(record, "container_image_registries", ContainerImageRegistry)
    elsif @display == "container_nodes" || session[:display] == "container_nodes" && params[:display].nil?
      show_container_display(record, "container_nodes", ContainerNode)
    elsif @display == "persistent_volumes" || session[:display] == "persistent_volumes" && params[:display].nil?
      show_container_display(record, "persistent_volumes", PersistentVolume)
    elsif @display == "container_builds" || session[:display] == "container_builds" && params[:display].nil?
      show_container_display(record, "container_builds", ContainerBuild)
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
    drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => record.name, :title => title},
                    :url  => "/#{alt_controller_name || controller_name}/show/#{record.id}?display=#{@display}")
    @view, @pages = get_view(clazz, :parent => record)  # Get the records (into a view) and the paginator
    @showtype = @display
    notify_about_unauthorized_items(title, ui_lookup(:tables => @table_name))
  end

  # Scan all selected or single displayed image(s)
  def scan_images
    assert_privileges("image_scan")
    showlist = @lastaction == "show_list"
    images = showlist ? find_checked_items : find_scan_item

    if images.empty?
      add_flash(_("No %{model} were selected for Analysis") % {:model => ui_lookup(:tables => "container_image")},
                :error)
    else
      process_scan_images(images)
    end

    showlist ? show_list : show
    images.count
  end

  def find_scan_item
    images = []
    if params[:id].nil? || ContainerImage.find_by_id(params[:id]).nil?
      add_flash(_("%{table} no longer exists") % {:table => ui_lookup(:table => "container_image")}, :error)
    else
      images.push(params[:id])
    end
    images
  end

  def process_scan_images(images)
    ContainerImage.where(:id => images).order("lower(name)").each do |image|
      image_name = image.name
      begin
        image.scan
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during 'Analysis': %{message}") %
                      {:model   => ui_lookup(:model => "ContainerImage"),
                       :name    => image_name,
                       :message => bang.message},
                  :error) # Push msg and error flag
      else
        add_flash(_("\"%{record}\": Analysis successfully initiated") % {:record => image_name})
      end
    end
  end
end
