module ContainersCommonMixin
  extend ActiveSupport::Concern

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
    model = self.class.model
    tag(model) if params[:pressed] == "#{params[:controller]}_tag"
    if [ContainerReplicator, ContainerGroup, ContainerNode, ContainerImage].include?(model)
      assign_policies(model) if params[:pressed] == "#{model.name.underscore}_protect"
      check_compliance(model) if params[:pressed] == "#{model.name.underscore}_check_compliance"
    end
    return if ["#{params[:controller]}_tag"].include?(params[:pressed]) && @flash_array.nil? # Tag screen showing

    # Handle scan
    if params[:pressed] == "container_image_scan"
      scan_images

      if @lastaction == "show"
        javascript_flash
      else
        replace_main_div :partial => "layouts/gtl"
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
    elsif @display == "compliance_history"
      count = params[:count] ? params[:count].to_i : 10
      update_session_for_compliance_history(record, count)
      drop_breadcrumb_for_compliance_history(record, controller_name, count)
      @showtype = @display
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
    elsif @display == "container_templates" || session[:display] == "container_templates" && params[:display].nil?
      show_container_display(record, "container_templates", ContainerTemplate)
    end
    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def update_session_for_compliance_history(record, count)
    @ch_tree = TreeBuilderComplianceHistory.new(:ch_tree, :ch, @sb, true, record)
    session[:ch_tree] = @ch_tree.tree_nodes
    session[:tree_name] = "ch_tree"
    session[:squash_open] = (count == 1)
  end

  def drop_breadcrumb_for_compliance_history(record, controller_name, count)
    if count == 1
      drop_breadcrumb(:name => _("%{name} (Latest Compliance Check)") % {:name => record.name},
                      :url  => "/#{controller_name}/show/#{record.id}?display=#{@display}&refresh=n")
    else
      drop_breadcrumb(
        :name => _("%{name} (Compliance History - Last %{number} Checks)") % {:name => record.name, :number => count},
        :url  => "/#{controller_name}/show/#{record.id}?display=#{@display}&refresh=n")
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

  def show_container_display(record, display, klass, alt_controller_name = nil)
    title = ui_lookup(:tables => display)
    drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => record.name, :title => title},
                    :url  => "/#{alt_controller_name || controller_name}/show/#{record.id}?display=#{@display}")
    @view, @pages = get_view(klass, :parent => record)  # Get the records (into a view) and the paginator
    @showtype = @display
  end

  # Scan all selected or single displayed image(s)
  def scan_images
    assert_privileges("image_scan")
    showlist = @lastaction == "show_list"
    ids = showlist ? find_checked_items : find_current_item(ContainerImage)

    if ids.empty?
      add_flash(_("No %{model} were selected for Analysis") % {:model => ui_lookup(:tables => "container_image")},
                :error)
    else
      process_scan_images(ids)
    end

    showlist ? show_list : show
    ids.count
  end

  def check_compliance(model)
    assert_privileges("#{model.name.underscore}_check_compliance")
    showlist = @lastaction == "show_list"
    ids = showlist ? find_checked_items : find_current_item(model)

    if ids.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:models => model.to_s),
                                                              :task  => "Compliance Check"}, :error)
    else
      process_check_compliance(model, ids)
    end

    showlist ? show_list : show
    ids.count
  end

  def find_current_item(model)
    if params[:id].nil? || model.find_by(:id => params[:id].to_i).nil?
      add_flash(_("%{model} no longer exists") % {:model => ui_lookup(:model => model.to_s)}, :error)
      []
    else
      [params[:id].to_i]
    end
  end

  def process_scan_images(ids)
    ContainerImage.where(:id => ids).order("lower(name)").each do |image|
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

  def process_check_compliance(model, ids)
    model.where(:id => ids).order("lower(name)").each do |entity|
      begin
        entity.check_compliance
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during 'Check Compliance': %{error}") %
                  {:model => ui_lookup(:model => model.to_s),
                   :name  => entity.name,
                   :error => bang.message},
                  :error) # Push msg and error flag
      else
        add_flash(_("\"%{record}\": Compliance check successfully initiated") % {:record => entity.name})
      end
    end
  end
end
