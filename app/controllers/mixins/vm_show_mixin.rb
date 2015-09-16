module VmShowMixin
  extend ActiveSupport::Concern

  def tabledata
    allowed_features = ApplicationController::Feature.allowed_features(features)
    set_active_elements(allowed_features.first)
    @nodetype, id = valid_active_node(x_node).split("_").last.split("-")
    model = case x_active_tree.to_s
            when "images_filter_tree"
              "ManageIQ::Providers::CloudManager::Template"
            when "images_tree"
              "ManageIQ::Providers::CloudManager::Template"
            when "instances_filter_tree"
              "ManageIQ::Providers::CloudManager::Vm"
            when "instances_tree"
              "ManageIQ::Providers::CloudManager::Vm"
            when "vandt_tree"
              "VmOrTemplate"
            when "vms_instances_filter_tree"
              "Vm"
            when "templates_images_filter_tree"
              "MiqTemplate"
            when "templates_filter_tree"
              "ManageIQ::Providers::InfraManager::Template"
            when "vms_filter_tree"
              "ManageIQ::Providers::InfraManager::Vm"
            end
    perpage = params[:length] != "NaN" ? params[:length].to_i : 20

    options = {:model => model, :page => params[:start].to_i / perpage + 1}
    if x_node == "root"
      options[:where_clause] = ["vms.type IN (?)", ManageIQ::Providers::InfraManager::Vm.subclasses.collect(&:name) + ManageIQ::Providers::InfraManager::Template.subclasses.collect(&:name)] if x_active_tree == :vandt_tree
    else
      if TreeBuilder.get_model_for_prefix(@nodetype) == "Hash"
        options[:where_clause] = ["vms.type IN (?)", ManageIQ::Providers::InfraManager::Vm.subclasses.collect(&:name) + ManageIQ::Providers::InfraManager::Template.subclasses.collect(&:name)] if x_active_tree == :vandt_tree
        if id == "orph"
          options[:where_clause] = MiqExpression.merge_where_clauses(options[:where_clause], VmOrTemplate::ORPHANED_CONDITIONS)
        elsif id == "arch"
          options[:where_clause] = MiqExpression.merge_where_clauses(options[:where_clause], VmOrTemplate::ARCHIVED_CONDITIONS)
        end
      elsif TreeBuilder.get_model_for_prefix(@nodetype) != "MiqSearch"
        rec = TreeBuilder.get_model_for_prefix(@nodetype).constantize.find(from_cid(id))
        options.merge!(:association => "#{@nodetype == "az" ? "vms" : "all_vms_and_templates"}", :parent => rec)
      end
    end
    db     = model.to_s
    dbname = db.gsub('::', '_').downcase # Get db name as text
    db_sym = dbname.to_sym # Get db name as symbol

    parent      = options[:parent] || nil             # Get passed in parent object
    association = options[:association] || nil        # Get passed in association (i.e. "users")

    # Build sorting keys - Use association name, if available, else dbname
    # need to add check for miqreportresult, need to use different sort in savedreports/report tree for saved reports list
    sort_prefix = association || (dbname == "miqreportresult" && x_active_tree ? x_active_tree.to_s : dbname)
    sortcol_sym = "#{sort_prefix}_sortcol".to_sym
    sortdir_sym = "#{sort_prefix}_sortdir".to_sym

    # Get the view for this db or use the existing one in the session
    @view = get_db_view(db.gsub('::', '_'), :association => association)

    # Check for changed settings in params
    @settings[:perpage][perpage_key(dbname)] = perpage

    # Get the current sort info, else get defaults from the view
    @sortcol = params[:order]['0']['column'].to_i
    @sortdir = params[:order]['0']['dir'].upcase

    session[sortcol_sym] = @sortcol
    session[sortdir_sym] = @sortdir

    @items_per_page = controller_name.downcase == "miq_policy" ? ONE_MILLION : get_view_pages_perpage(dbname)
    @items_per_page = ONE_MILLION if 'vm' == db_sym.to_s && controller_name == 'service'

    @current_page = options[:page]

    stxt = params[:search][:value].gsub("_", "`_") # Escape underscores
    stxt.gsub!("%", "`%") # and percents

    stxt = if stxt.starts_with?("*") && stxt.ends_with?("*") # Replace beginning/ending * chars with % for SQL
             "%#{stxt[1..-2]}%"
           elsif stxt.starts_with?("*")
             "%#{stxt[1..-1]}"
           elsif stxt.ends_with?("*")
             "#{stxt[0..-2]}%"
           else
             "%#{stxt}%"
           end

    if MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :case_sensitive_name_search)
      sub_filter = ["#{@view.db_class.table_name}.#{@view.col_order.first} like ? escape '`'", stxt]
    else
      sub_filter = ["lower(#{@view.db_class.table_name}.#{@view.col_order.first}) like ? escape '`'", stxt.downcase] unless @display
    end

    # Save the paged_view_search_options for download buttons to use later
    session[:paged_view_search_options] = {
      :parent              => parent ? minify_ar_object(parent) : nil,
      :parent_method       => options[:parent_method],
      :targets_hash        => true,
      :association         => association,
      :filter              => get_view_filter(options),
      :sub_filter          => sub_filter,
      :page                => options[:all_pages] ? 1 : @current_page,
      :per_page            => options[:all_pages] ? ONE_MILLION : @items_per_page,
      :where_clause        => get_view_where_clause(options),
      :named_scope         => options[:named_scope],
      :display_filter_hash => options[:display_filter_hash],
      :userid              => session[:userid]
    }

    # Call paged_view_search to fetch records and build the view.table and additional attrs
    @view.table, attrs = @view.paged_view_search(session[:paged_view_search_options])

    # adding filters/conditions for download reports
    if attrs && attrs[:user_filters] && attrs[:user_filters]["managed"]
      @view.user_categories = attrs[:user_filters]["managed"]
    end

    @view.extras[:total_count] = attrs[:total_count] if attrs[:total_count]
    @view.extras[:auth_count]  = attrs[:auth_count]  if attrs[:auth_count]

    @pages = get_view_pages(dbname, @view)
    @parent = parent
  end

  def explorer
    @tabledata = true
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
    allowed_features = ApplicationController::Feature.allowed_features(features)
    @trees = allowed_features.collect { |feature| feature.build_tree(@sb) }
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

    render :layout => "application" unless redirected
  end

  def set_form_locals_for_sysprep
    _partial, action, @right_cell_text = set_right_cell_vars
    locals = {:submit_button => true,
              :no_reset      => true,
              :action_url    => action
             }
    @x_edit_buttons_locals = locals
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

  def set_active_elements(feature)
    if feature
      self.x_active_tree   ||= feature.tree_list_name
      self.x_active_accord ||= feature.accord_name
    end
    get_node_info(x_node)
  end

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
    TreeBuilder.tree_add_child_nodes(@sb, x_tree[:klass_name], id)
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

    case @display
    when "download_pdf", "main", "summary_only"
      @button_group = @record.kind_of?(MiqTemplate) ? "miq_template" : "vm"

      get_tagdata(@record)
      @showtype = "main"
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

  def breadcrumb_name(model)
    ui_lookup_for_model(model || self.class.model.name).pluralize
  end
end
