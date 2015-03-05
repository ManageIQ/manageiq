module VmShowMixin
  extend ActiveSupport::Concern

  def explorer
    @explorer = true
    @lastaction = "explorer"
    @timeline = @timeline_filter = true    #need to set these to load timelines on vm show screen
    if params[:menu_click]              # Came in from a chart context menu click
      @_params[:id] = x_node.split("_").last.split("-").last
      @explorer = true
      perf_menu_click                    # Handle the menu action
      return
    end
    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    if params[:accordion]
      self.x_active_tree   = "#{params[:accordion]}_tree"
      self.x_active_accord = params[:accordion]
    end
    if params[:button]
      @miq_after_onload = "miqAjax('/#{controller_name}/x_button?pressed=#{params[:button]}');"
    end

    # Build the Explorer screen from scratch
    allowed_features = features.select { |f| role_allows(:feature => f.role) }
    allowed_features.each { |feature| build_vm_tree(feature.name, feature.tree_name) }

    @trees = allowed_features.map(&:tree_list_name)
    @accords = allowed_features.map(&:accord_hash)

    params.merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)

    if params[:commit] == "Upload" && session.fetch_path(:edit, :new, :sysprep_enabled, 1) == "Sysprep Answer File"
      upload_sysprep_file
      set_form_locals_for_sysprep
    end
    if params[:id]
      # if you click on a link to VM on a dashboard widget that will redirect you
      # to explorer with params[:id] and you get into the true branch
      redirected = set_elements_and_redirect_unauthorized_user
    else
      set_active_elements(allowed_features.first) unless @upload_sysprep_file
    end

    render :layout => "explorer" unless redirected
  end

  def set_form_locals_for_sysprep
    _partial, action, @right_cell_text = set_right_cell_vars
    locals = {:submit_button => true,
              :no_reset      => true,
              :action_url    => action
             }
    @temp[:x_edit_buttons_locals] = locals
  end

  # VM or Template show selected, redirect to proper controller, to get links on tasks screen working
  def vm_show
    record = VmOrTemplate.find_by_id(from_cid(params[:id]))
    redirect_to :action => 'show', :controller=>record.class.base_model.to_s.underscore, :id=>record.id
  end

  # find the vm that was chosen
  def identify_vm
    return @record = identify_record(params[:id])
  end

  private

  def set_active_elements_authorized_user(tree_name, accord_name, add_nodes, klass, id)
    self.x_active_tree   = tree_name
    self.x_active_accord = accord_name
    if add_nodes
      nodes = open_parent_nodes(klass.find_by_id(id))
      # Create the hash so the view knows to highlight the selected node
      @add_nodes = {}
      @add_nodes[tree_name.to_sym] = nodes if nodes # Set nodes that need to be added, if any
    end
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    return x_get_child_nodes_dynatree(x_active_tree, id)
  end

  def show_record(id = nil)
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"
    @vm = @record = identify_record(id, VmOrTemplate) unless @record

    if @record == nil
      add_flash(_("Error: Record no longer exists in the database"), :error)
      if request.xml_http_request?  && params[:id]  # Is this an Ajax request clicking on a node that no longer exists?
        @delete_node = params[:id]                  # Set node to be removed from the tree
      end
      return
    end

    if @record.class.base_model.to_s == "MiqTemplate"
      rec_cls = @record.class.base_model.to_s.underscore
    else
      rec_cls = "vm"
    end
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@record)
      @showtype = "main"
      @button_group = "#{rec_cls}"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)

    when "performance"
      @showtype = "performance"
      perf_gen_init_options                # Initialize perf chart options, charts will be generated async

    when "timeline"
      @showtype = "timeline"
      tl_build_timeline                    # Create the timeline report
    end

    unless @record.hardware.nil?
      @record_notes = @record.hardware.annotation.nil? ? "<No notes have been entered for this VM>" : @record.hardware.annotation
    end
    set_config(@record)
    get_host_for_vm(@record)
    session[:tl_record_id] = @record.id
  end

  def get_filters
    session[:vm_filters]
  end

  def get_session_data
    @title          = "VMs And Templates"
    @layout         = controller_name
    @lastaction     = session[:vm_lastaction]
    @showtype       = session[:vm_showtype]
    @base           = session[:vm_compare_base]
    @filters        = get_filters
    @catinfo        = session[:vm_catinfo]
    @cats           = session[:vm_cats]
    @display        = session[:vm_display]
    @polArr         = session[:polArr] || ""          # current tags in effect
    @policy_options = session[:policy_options] || ""
  end

  def set_session_data
    session[:vm_lastaction]   = @lastaction
    session[:vm_showtype]     = @showtype
    session[:miq_compressed]  = @compressed unless @compressed.nil?
    session[:miq_exists_mode] = @exists_mode unless @exists_mode.nil?
    session[:vm_compare_base] = @base
    session[:vm_filters]      = @filters
    session[:vm_catinfo]      = @catinfo
    session[:vm_cats]         = @cats
    session[:vm_display]      = @display unless @display.nil?
    session[:polArr]          = @polArr unless @polArr.nil?
    session[:policy_options]  = @policy_options unless @policy_options.nil?
  end

  # Build a VM & Template explorer tree
  def build_vm_tree(type, name)
    x_tree_init(name, type, vm_model_from_active_tree(name),
      :open_all => type == :filter
    )
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root = tree_nodes.first
    root[:icon] = "vm.png"
    root[:title], root[:tooltip] = TreeBuilder.root_options(name)

    @temp[name] = tree_nodes.to_json  # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end
end
