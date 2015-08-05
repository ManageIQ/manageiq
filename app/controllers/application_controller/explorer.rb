# Explorer generic methods included in application.rb
module ApplicationController::Explorer
  extend ActiveSupport::Concern

  # Historical tree item selected
  def x_history
    @hist = x_tree_history[params[:item].to_i]  # Set instance var so we know hist button was pressed
    if @hist[:button]         # Button press from show screen
      self.x_node = @hist[:id]
      nodetype, params[:id] = x_node.split("_").last.split("-")
      params[:x_show] = @hist[:item]
      params[:pressed] = @hist[:button] # Look like we came in with this action
      params[:display] = @hist[:display]
      x_button
    elsif @hist[:display]           # Display link from show screen
      self.x_node = @hist[:id]
      nodetype, params[:id] = x_node.split("_").last.split("-")
      params[:display] = @hist[:display]
      show
    elsif @hist[:action]          # Action link from show screen
      self.x_node = @hist[:id]
      nodetype, params[:id] = x_node.split("_").last.split("-")
      params[:x_show] = @hist[:item]
      params[:action] = @hist[:action]  # Look like we came in with this action
      session[:view] = @hist[:view] if @hist[:view]
      self.send(@hist[:action])
    else                        # Normal explorer tree/link click
      params[:id] = @hist[:id]
      tree_select
    end
  end

  # Capture explorer settings changes and save them for a user
  def x_settings_changed
    @edit = session[:edit]  # Set @edit so it is preserved in the session object
    @keep_compare = true if session[:miq_compare] # if explorer was resized when on compare screen, keep compare object in session

    if params.key?(:width)
      # Store the new settings in the user record and in @settings (session)
      db_user = current_user
      unless db_user.nil?
        db_user.settings[:explorer] ||= {}
        db_user.settings[:explorer][params[:controller]] ||= {}
        db_user.settings[:explorer][params[:controller]][:width] = params['width']
        @settings[:explorer] = db_user.settings[:explorer]
        db_user.save
      end
    end

    render :js => ''
  end

  # FIXME: the code below has to be converted into proper actions called though
  # proper routes, this is just a small step to fix the current situation
  X_BUTTON_ALLOWED_ACTIONS = {
    # group 1
    'check_compliance' => :s1, 'collect_running_processes' => :s1, 'delete'              => :s1,
    'snapshot_delete'  => :s1, 'snapshot_delete_all' => :s1,
    'refresh'          => :s1, 'scan'                      => :s1, 'guest_shutdown'      => :s1,
    'guest_restart'    => :s1, 'retire_now'                => :s1, 'snapshot_revert'     => :s1,
    'start'            => :s1, 'stop'                      => :s1, 'suspend'             => :s1,
    'reset'            => :s1, 'terminate'                 => :s1, 'pause'               => :s1,

    # group 2
    'clone'     => :s2, 'compare'          => :s2, 'drift'           => :s2,
    'edit'      => :s2, 'evm_relationship' => :s2, 'migrate'         => :s2,
    'ownership' => :s2, 'policy_sim'       => :s2, 'protect'         => :s2,
    'publish'   => :s2, 'reconfigure'      => :s2, 'miq_request_new' => :s2,
    'retire'    => :s2, 'right_size'       => :s2, 'snapshot_add'    => :s2,
    'tag'       => :s2, 'timeline'         => :s2,

    # specials
    'perf'         => :show,
    'download_pdf' => :show,
    'perf_reload'  => :perf_chart_chooser,
    'perf_refresh' => :perf_refresh_data,
  }.freeze

  def x_button
    model, action = pressed2model_action(params[:pressed])

    allowed_models = %w(common image instance vm miq_template provider)
    raise ActionController::RoutingError.new('invalid button action') unless
      allowed_models.include?(model)

    # guard this 'router' by matching against a list of allowed actions
    raise ActionController::RoutingError.new('invalid button action') unless
      X_BUTTON_ALLOWED_ACTIONS.key?(action)

    @explorer = true

    # Process model actions that are currently implemented
    if X_BUTTON_ALLOWED_ACTIONS[action] == :s1
      self.send(params[:pressed])
    elsif X_BUTTON_ALLOWED_ACTIONS[action] == :s2
      # don't need to set params[:id] and do find_checked_items for methods
      # like ownership, the code in those methods handle it
      if ['edit', 'right_size'].include?(action)
        @_params[:id] = (params[:id] ? [params[:id]] : find_checked_items)[0]
      end
      if ['protect', 'tag'].include?(action)
        self.send(params[:pressed], VmOrTemplate)
      else
        self.send(params[:pressed])
      end
      # if error rendered, do not render any further, do not record history
      # non-error rendering is done below through @refresh_partial
      return if performed?
      @sb[:model]  = model
      @sb[:action] = action
    elsif action == 'perf'
      @sb[:model]  = model
      @sb[:action] = action
      show
    elsif action == 'download_pdf'
      show
    elsif action == 'perf_reload'
      perf_chart_chooser
      return
    elsif action == 'perf_refresh'
      perf_refresh_data
    end

    return if performed?
    # no need to render anything, method will render flash message when async task is completed

    x_button_response(model, action)
  end

  def x_button_response(model, action)
    if @refresh_partial == "layouts/flash_msg"
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    elsif @refresh_partial
      replace_right_cell unless action == 'download_pdf' # no need to render anything when download_pdf button is pressed on summary screen
    else
      add_flash(_("Button not yet implemented") + " #{model}:#{action}", :error) unless @flash_array
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Handle name searches typed into list view explorer screens
  def x_search_by_name
    @explorer = true
    params[:id] = x_node  # Get the current tree node id
    tree_select
  end

  private ############################

  # Add an item to the tree history array
  def x_history_add_item(options)
    x_tree_history.delete_if do |item|
      ![:id, :action, :button, :display, :item].find { |key| item[key] != options[key] }
    end
    x_tree_history.unshift(options).slice!(11..-1)
  end

  def x_edit_tags_reset(db)
    @tagging = session[:tag_db] = db
    @object_ids = find_checked_items
    if params[:button] == "reset"
      id = params[:id] if params[:id]
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}","replace_cell__explorer")
      @object_ids = @edit[:object_ids]
      session[:tag_db] = @tagging = @edit[:tagging]
    else
      @object_ids[0] = params[:id] if @object_ids.blank? && params[:id]
      session[:tag_db] = @tagging = params[:tagging] if params[:tagging]
    end

    @gtl_type = "list"  # No quad icons for user/group list views
    x_tags_set_form_vars
    @in_a_form = true
    session[:changed] = false
    add_flash(_("All changes have been reset"), :warning)  if params[:button] == "reset"
    @right_cell_text = _("Editing %{model} for \"%{name}\"") % {:name=>ui_lookup(:models=>@tagging), :model=>"#{session[:customer_name]} Tags"}
    replace_right_cell(@sb[:action])
  end

  # Set form vars for tag editor
  def x_tags_set_form_vars
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:key] = "#{session[:tag_db]}_edit_tags__#{@object_ids[0]}"
    @edit[:object_ids] = @object_ids
    @edit[:tagging] = @tagging
    session[:assigned_filters] = assigned_filters
    tag_edit_build_screen
    build_targets_hash(@tagitems)

    @edit[:current] = copy_hash(@edit[:new])
  end

  def x_edit_tags_cancel
    id = params[:id]
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}","replace_cell__explorer")
    add_flash(_("%s was cancelled by the user") % "Tag Edit")
    get_node_info(x_node)
    @edit = nil # clean out the saved info
    replace_right_cell
  end

  def x_edit_tags_save
    tagging_edit_tags_save_and_replace_right_cell
  end

  # Build an explorer tree, from scratch
  def x_build_dynatree(options)
    # Options:
    # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
    # :leaf                   # Model name of leaf nodes, i.e. "Vm"
    # :open_nodes             # Tree node ids of currently open nodes
    # :add_root               # If true, put a root node at the top
    # :full_ids               # stack parent id on top of each node id

    roots = x_get_tree_objects(options.merge({
                                                 :userid=>session[:userid], # Userid for RBAC filtering
                                                 :parent=>nil               # Asking for roots, no parent
                                             }))

    if [:vandt].include?(options[:type]) # :vandt tree is built in a "new" full tree style
      root_nodes = roots[0...-2]
      roots      = roots[-2, 2] # but, still build the archive and orphan trees the old way
    else
      root_nodes = Array.new
    end

    roots.each do |r|
      root_nodes += x_build_node_dynatree(r, nil, options)  # Build the node(s), passing in the parent object and the options
    end

    if options[:add_root]
      node = Hash.new                         # Build the root node
      node[:key] = "root"
      node[:children] = root_nodes
      node[:expand] = true
      return [node]                           # Return top node as an array
    else
      return root_nodes
    end
  end

  # Get objects (or count) to put into a tree under a parent node, based on the tree type
  # TODO: Make the called methods honor RBAC for passed in userid
  # TODO: Perhaps push the object sorting down to SQL, if possible
  def x_get_tree_objects(options)
    # Options used:
    # :parent                 # Parent object for which we need child tree nodes returned
    # :userid                 # Signed in user's id
    # :count_only             # Return only the count if true
    # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
    # :leaf                   # Model name of leaf nodes, i.e. "Vm"
    # :open_all               # if true open all node (no autoload)

    object = options[:parent]
    children_or_count = case object
    when nil                 then x_get_tree_roots(options)
    when AvailabilityZone    then x_get_tree_az_kids(object, options)
    when CustomButtonSet     then x_get_tree_aset_kids(object, options)
    when Dialog              then x_get_tree_dialog_kids(object, options)
    when DialogTab           then x_get_tree_dialog_tab_kids(object, options)
    when DialogGroup         then x_get_tree_dialog_group_kids(object, options)
    when ExtManagementSystem then x_get_tree_ems_kids(object, options)
    when EmsFolder           then object.is_datacenter ?
                                  x_get_tree_datacenter_kids(object, options) :
                                  x_get_tree_folder_kids(object, options)
    when EmsCluster          then x_get_tree_cluster_kids(object, options)
    when Host		             then x_get_tree_host_kids(object, options)
    when LdapRegion		       then x_get_tree_lr_kids(object, options)
    when MiqAlertSet		     then x_get_tree_ap_kids(object, options)
    when MiqEvent            then options[:tree] != :event_tree ?
                                  x_get_tree_ev_kids(object, options) : nil
    when MiqGroup            then options[:tree] == :db_tree ?
                                  x_get_tree_g_kids(object, options) : nil
    when MiqPolicySet		     then x_get_tree_pp_kids(object, options)
    when MiqPolicy		       then x_get_tree_p_kids(object, options)
    when MiqRegion		       then x_get_tree_region_kids(object, options)
    when MiqReport		       then x_get_tree_r_kids(object, options)
    when ResourcePool		     then x_get_tree_rp_kids(object, options)
    when ServiceTemplate		 then x_get_tree_st_kids(object, options)
    when ServiceResource		 then x_get_tree_sr_kids(object, options)
    when VmdbTableEvm		     then x_get_tree_vmdb_table_kids(object, options)
    when Zone		             then x_get_tree_zone_kids(object, options)
    when Hash                then x_get_tree_custom_kids(object, options)
    end
    children_or_count || (options[:count_only] ? 0 : [])
  end

  # Return a tree node for the passed in object
  def x_build_node(object, pid, options)    # Called with object, tree node parent id, tree options
    @sb[:my_server_id] = MiqServer.my_server(true).id      if object.kind_of?(MiqServer)
    @sb[:my_zone]      = MiqServer.my_server(true).my_zone if object.kind_of?(Zone)

    options[:is_current] =
      ((object.kind_of?(MiqServer) && @sb[:my_server_id] == object.id) ||
       (object.kind_of?(Zone)      && @sb[:my_zone]      == object.name))

    options.merge!(:active_tree => x_active_tree)
    options.merge!({:parent_id => pid}) if object.kind_of?(MiqEvent) || object.kind_of?(MiqAction)

    # open nodes to show selected automate entry point
    x_tree(options[:tree])[:open_nodes] = @open_nodes.dup if @open_nodes

    node = TreeNodeBuilder.build(object, pid, options)

    case object
    when Service, ServiceTemplate
      add_pictures_to_sync(object.picture.id) if object.picture
    when MiqGroup
      # loading nodes under event node incase these were cliked on policy details screen and not yet loaded in the tree
      x_tree(options[:tree])[:open_nodes].push("#{pid}_ev-#{to_cid(object.id)}") if [:policy_profile_tree, :policy_tree].include?(options[:tree])
    when Hash
      @sb[:auto_select_node] = node['id']||node[:key] if options[:active_tree] == :vmdb_tree
    end

    if [:policy_profile_tree, :policy_tree].include?(options[:tree])
      x_tree(options[:tree])[:open_nodes].push(node[:key])
    end

    # Process the node's children
    if x_tree(options[:tree])[:open_nodes].include?(node[:key]) || options[:open_all]
      kids = []
      x_get_tree_objects(options.merge({:parent => object})).each do |o|
        kids += x_build_node(o, node[:key], options)
      end
      node[:children] = kids unless kids.empty?
    else
      if x_get_tree_objects(options.merge({:parent => object, :count_only => true})) > 0
        node[:isLazy] = true  # set child flag if children exist
      end
    end
    [node]
  end

  def x_build_node_dynatree(object, pid, options)   # Called with object, tree node parent id, tree options
    x_build_node(object, pid, options)
  end

  # Build a tree node id based on the object
  def x_build_node_id(object, pid = nil, options = {})
    TreeNodeBuilder.build_id(object, pid, options)
  end

  # Get the children of a dynatree node that is being expanded (autoloaded)
  # FIXME: still used by reports and control, replace with TreeBuilder.x_get_child_nodes
  def x_get_child_nodes_dynatree(tree, id)
    model, rec_id, prefix = TreeBuilder.extract_node_model_and_id(id)

    if model == "Hash"
      object = {:type=>prefix, :id=>rec_id, :full_id=>id}
    elsif model.nil? && [:sandt_tree, :svccat_tree, :stcat_tree].include?(x_active_tree)   #creating empty record to show items under unassigned catalog node
      object = ServiceTemplateCatalog.new()   # Get the object from the DB
    else
      object = model.constantize.find(from_cid(rec_id))   # Get the object from the DB
    end

    kids = Array.new
    x_tree(tree)[:open_nodes].push(id) unless x_tree(tree)[:open_nodes].include?(id) # Save node as open

    options = x_tree(tree)         # Get options from sandbox

    # Process the node's children
    x_get_tree_objects(options.merge({:parent=>object})).each do |o|
      kids += x_build_node_dynatree(o, id, options)
    end

    kids
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only = options[:count_only]
    case options[:type]
    when :export
      export_children = [
        {:id => "exportcustomreports", :tree => "export_tree", :text => "Custom Reports", :image => "report"},
        {:id => "exportwidgets", :tree => "export_tree", :text => "Widgets", :image => "report"}
      ]
      return count_only ? export_children.length : export_children
    when :ab
      @resolve[:target_classes] = Hash.new
      CustomButton.button_classes.each{|db| @resolve[:target_classes][db] = ui_lookup(:model=>db)}
      #deleting ServiceTemplate, don't need to show those in automate buttons tree
      @resolve[:target_classes].delete_if {|key, value| key == "ServiceTemplate" }
      @sb[:target_classes] = @resolve[:target_classes].invert
      @resolve[:target_classes] = Array(@resolve[:target_classes].invert).sort
      @resolve[:target_classes].collect{|typ| {:id=>"ab_#{typ[1]}", :text=>typ[0], :image=>buttons_node_image(typ[1]), :tip=>typ[0]}}
    when :ae,:automate
      objects = MiqAeNamespace.all(:conditions => ["parent_id is null AND name<>?" ,"$"]).sort_by { |ns| [ns.display_name.to_s, ns.name.to_s] }
      return count_only ? objects.length : objects
    when :action
      objects = MiqAction.all.sort_by { |a| a.description.downcase }
      return count_only ? objects.length : objects
    when :alert
      objects = MiqAlert.all.sort_by { |a| a.description.downcase }
      return count_only ? objects.length : objects
    when :alert_profile
      objects = Array.new
      MiqAlert.base_tables.sort_by { |a| ui_lookup(:model=>a) }.each do |db|
        objects.push({:id=>db, :text=>"#{ui_lookup(:model=>db)} Alert Profiles", :image=>db.underscore.downcase, :tip=>"#{ui_lookup(:model=>db)} Alert Profiles"})
        # Set alert profile folder nodes to open so we pre-load all children
        n = "xx-#{db}"
        x_tree(options[:tree])[:open_nodes].push(n) unless x_tree(options[:tree])[:open_nodes].include?(n)
      end
      return count_only ? objects.length : objects
    when :condition
      objects = Array.new
      objects.push({:id=>"host", :text=>"Host Conditions", :image=>"host", :tip=>"Host Conditions"})
      objects.push({:id=>"vm", :text=>"All VM and Instance Conditions", :image=>"vm", :tip=>"All VM and Instance Conditions"})
      return count_only ? objects.length : objects
    when :db
      objects = Array.new
      @default_ws = MiqWidgetSet.where_unique_on("default", nil, nil).where(:read_only => true).first
      text = "#{@default_ws.description} (#{@default_ws.name})"
      objects.push(:id=>to_cid(@default_ws.id),:text=>text, :image=>"dashboard", :tip=>text )
      objects.push({:id=>"g", :text=>"All Groups", :image=>"folder", :tip=>"All Groups"})
      return objects
    when :dialog_edit
      objects = params[:id] ? [Dialog.find_by_id(params[:id])] : [Dialog.new(:label=>"Dialog")]
      return count_only ? objects.length : objects
    when :dialogs
      objects = rbac_filtered_objects(Dialog.all).sort_by { |a| a.label.downcase }
      return count_only ? objects.length : objects
    when :event
      objects = MiqPolicy.all_policy_events.sort_by {|a| a.description.downcase }
      return count_only ? objects.length : objects
    when :old_dialogs
      MiqDialog::DIALOG_TYPES.sort.collect{|typ| {:id=>"MiqDialog_#{typ[1]}", :text=>typ[0], :image=>"folder", :tip=>typ[0]}}
    when :policy_profile
      objects = MiqPolicySet.all.sort_by { |a| a.description.downcase }
      return count_only ? objects.length : objects
    when :policy
      objects = Array.new
      ["xx-compliance", "xx-control"].each do |n| # Push folder node ids onto open_nodes array
        x_tree(options[:tree])[:open_nodes].push(n) unless x_tree(options[:tree])[:open_nodes].include?(n)
      end
      objects.push({:id=>"compliance", :text=>"Compliance Policies", :image=>"compliance", :tip=>"Compliance Policies"})
      objects.push({:id=>"control", :text=>"Control Policies", :image=>"control", :tip=>"Control Policies"})
      return count_only ? objects.length : objects
    when :reports
      objects = Array.new
      @sb[:rpt_menu].each_with_index do |r,i|
        objects.push({:id=>"#{i}", :text=>r[0], :image=>"#{@sb[:grp_title] == r[0] ? "blue_folder" : "folder"}", :tip=>r[0]})
        #load next level of folders when building the tree
        x_tree(options[:tree])[:open_nodes].push("xx-#{i}")
      end
      return objects
    when :roles
      user = current_user
      if user.super_admin_user?
        roles = MiqGroup.all
      else
        roles = [MiqGroup.find_by_id(user.current_group_id)]
      end
      return options[:count_only] ? roles.count : roles.sort_by { |a| a.name.downcase }
    when :schedules
      if session[:userrole] == "super_administrator"  # Super admins see all report schedules
        objects = MiqSchedule.all(:conditions=>["towhat=?", "MiqReport"])
      else
        objects = MiqSchedule.all(:conditions=>["towhat=? AND userid=?", "MiqReport", session[:userid]])
      end
      return options[:count_only] ? objects.count : objects.sort_by { |a| a.name.downcase }
    when :vandt, :images, :instances, :filter
      raise "x_get_tree_roots called for #{options[:type]} tree"
    when :handc
      objects = rbac_filtered_objects(ManageIQ::Providers::InfraManager.order("lower(name)"), :match_via_descendants => "VmOrTemplate")
      if count_only
        return objects.length + 2
      else
        return objects +
          [
            {:id=>"arch", :text=>"<Archived>", :image=>"currentstate-archived", :tip=>"Archived VMs and Templates"},
            {:id=>"orph", :text=>"<Orphaned>", :image=>"currentstate-orphaned", :tip=>"Orphaned VMs and Templates"}
          ]
      end
    when :savedreports
      # Saving the unique folder id's that hold reports under them, to use them in view to generate link
      @sb[:folder_ids] = Hash.new
      g = current_user.admin_user? ? nil : session[:group]
      MiqReport.having_report_results(:miq_group => g, :select => [:id, :name]).each do |r|
        @sb[:folder_ids][r.name] = to_cid(r.id.to_i)
      end
      objects = Array.new
      @sb[:folder_ids].sort.each_with_index do |p,i|
        objects.push({:id=>p[1], :text=>p[0], :image=>"report", :tip=>p[0]})
      end
      return objects
    when :stcat
      objects = rbac_filtered_objects(ServiceTemplateCatalog.all).sort_by { |a| a.name.downcase }
      return count_only ? objects.length : objects
    when :svccat
      objects = rbac_filtered_objects(ServiceTemplateCatalog.all).sort_by { |a| a.name.downcase }
      filtered_objects = Array.new
      #only show catalogs nodes that have any servicetemplate records under them
      objects.each do |object|
        items = rbac_filtered_objects(object.service_templates)
        filtered_objects.push(object) if !items.empty?
      end
      return count_only ? filtered_objects.length : filtered_objects
    when :bottlenecks, :utilization
      ent = MiqEnterprise.my_enterprise
      objects = ent.miq_regions.sort_by { |a| a.description.to_s.downcase }
      return count_only ? objects.length : objects
    when :widgets
      objects = Array.new
      WIDGET_TYPES.keys.each do |w|
        objects.push({:id=>w, :text=>WIDGET_TYPES[w], :image=>"folder", :tip=>WIDGET_TYPES[w]})
      end
      return objects
    else
      return count_only ? 0 : []
    end
  end

  # Get ems children count/array
  def x_get_tree_ems_kids(object, options)
    raise "x_get_tree_ems_kids called for #{options[:type]} tree"
  end

  def x_get_tree_datacenter_kids(object, options)
    count_only = options[:count_only]
    case options[:type]
    when :handc
      objects = rbac_filtered_objects(object.clusters).sort_by { |a| a.name.downcase }
      object.folders.each do |f|
        if f.name == "vm"                 # Don't add vm folder children
        elsif f.name == "host"            # Add host folder children
          objects += rbac_filtered_objects(f.folders).sort_by { |a| a.name.downcase }
          objects += rbac_filtered_objects(f.clusters).sort_by { |a| a.name.downcase }
          objects += rbac_filtered_objects(f.hosts).sort_by { |a| a.name.downcase }
        else                              # add in other folders
          objects += rbac_filtered_objects([f])
        end
      end
      return count_only ? objects.length : objects
    else
      return count_only ? 0 : []
    end
  end

  def x_get_tree_folder_kids(object, options)
    count_only = options[:count_only]
    case options[:type]
    when :handc
      objects =  rbac_filtered_objects(object.folders_only, :match_via_descendants => "VmOrTemplate").sort_by { |a| a.name.downcase }
      objects += rbac_filtered_objects(object.datacenters_only, :match_via_descendants => "VmOrTemplate").sort_by { |a| a.name.downcase }
      objects += rbac_filtered_objects(object.clusters, :match_via_descendants => "VmOrTemplate").sort_by { |a| a.name.downcase }
      objects += rbac_filtered_objects(object.hosts, :match_via_descendants => "VmOrTemplate").sort_by { |a| a.name.downcase }
      objects += rbac_filtered_objects(object.vms_and_templates).sort_by { |a| a.name.downcase }
      return count_only ? objects.length : objects
    else
      return count_only ? 0 : []
    end
  end

  def x_get_tree_cluster_kids(object, options)
    objects =  rbac_filtered_objects(object.hosts).sort_by { |a| a.name.downcase }
    if ![:bottlenecks_tree, :utilization_tree].include?(x_active_tree)
      objects += rbac_filtered_objects(object.resource_pools).sort_by { |a| a.name.downcase }
      objects += rbac_filtered_objects(object.vms).sort_by { |a| a.name.downcase }
    end
    return options[:count_only] ? objects.length : objects
  end

  def x_get_tree_host_kids(object, options)
    if [:bottlenecks_tree, :utilization_tree].include?(x_active_tree)
      raise "ERROR: should not get here"
      objects = Array.new
    else
      objects = rbac_filtered_objects(object.resource_pools).sort_by { |a| a.name.downcase }.delete_if(&:is_default)
      if object.default_resource_pool           # Go thru default RP VMs
        objects += rbac_filtered_objects(object.default_resource_pool.vms).sort_by { |a| a.name.downcase }
      end
    end
    return options[:count_only] ? objects.length : objects
  end

  def x_get_tree_rp_kids(object, options)
    objects =  rbac_filtered_objects(object.resource_pools).sort_by { |a| a.name.downcase }
    objects += rbac_filtered_objects(object.vmss).sort_by { |a| a.name.downcase }
    return options[:count_only] ? objects.length : objects
  end

  def x_get_tree_lr_kids(object, options)
    if options[:count_only]
      return (object.ldap_domains.count)
    else
      return (object.ldap_domains.sort_by { |a| a.name.to_s })
    end
  end

  def x_get_tree_zone_kids(object, options)
    if options[:count_only]
      return (object.miq_servers.count)
    else
      return (object.miq_servers.sort_by { |a| a.name.to_s })
    end
  end

  def x_get_tree_region_kids(object, options)
    emses     = [:bottlenecks, :utilization].include?(options[:type]) ?
                    rbac_filtered_objects(object.ems_infras) :
                    rbac_filtered_objects(object.ext_management_systems)
    storages  = rbac_filtered_objects(object.storages)
    if options[:count_only]
      return emses.count + storages.count
    else
      objects = Array.new
      if emses.count > 0
        objects.push({:id=>"folder_e_xx-#{to_cid(object.id)}", :text=>ui_lookup(:tables=>"ext_management_systems"), :image=>"folder", :tip=>"#{ui_lookup(:tables=>"ext_management_systems")} (Click to open)"})
      end
      if storages.count > 0
        objects.push({:id=>"folder_ds_xx-#{to_cid(object.id)}", :text=>ui_lookup(:tables=>"storages"), :image=>"folder", :tip=>"#{ui_lookup(:tables=>"storages")} (Click to open)"})
      end
      return objects
    end
  end

  def x_get_tree_g_kids(object, options)
    objects = Array.new
    #dashboard nodes under each group
    widgetsets = MiqWidgetSet.find_all_by_owner_type_and_owner_id("MiqGroup",object.id)
    #if dashboard sequence was saved, build tree using that, else sort by name and build the tree
    if object.settings && object.settings[:dashboard_order]
      object.settings[:dashboard_order].each do |ws_id|
        widgetsets.each do |ws|
          if ws_id == ws.id
            objects.push(ws)
          end
        end
      end
    else
      objects = copy_array(widgetsets)
    end
    return options[:count_only] ? widgetsets.count : widgetsets.sort_by { |a| a.name.to_s }
  end

  def x_get_tree_r_kids(object, options)
    view, pages = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(object.id), :all_pages=>true)
    saved_reps = view.table.data
    objects = Array.new
    saved_reps.each do |s|
      objects.push(MiqReportResult.find_by_id(s["id"]))
    end
    if options[:count_only]
      return objects.count
    else
      return (objects.sort_by { |a| a.name.downcase })
    end
  end

  #get custombuttonset records to build uanssigned/assigned folder nodes
  def x_get_tree_aset_kids(object, options)
    if options[:count_only]
      if object.id.nil?
        objects = Array.new
        CustomButton.buttons_for(object.name.split('|').last.split('-').last).each do |uri|
          objects.push(uri) if uri.parent.nil?
        end
        return objects.count
      else
        return object.members.count
      end
    else
      if object.id.nil?
        objects = Array.new
        CustomButton.buttons_for(object.name.split('|').last.split('-').last).each do |uri|
          objects.push(uri) if uri.parent.nil?
        end
        return objects.sort_by(&:name)
      else
        #need to show button nodes in button order that they were saved in
        button_order = object[:set_data] && object[:set_data][:button_order] ? object[:set_data][:button_order] : nil
        objects = Array.new
        if button_order     # show assigned buttons in order they were saved
          button_order.each do |bidx|
            object.members.each do |b|
              if bidx == b.id
                objects.push(b) unless objects.include?(b)
              end
            end
          end
        end
        return objects
      end
    end
  end

  def x_get_tree_ap_kids(object, options)
    if options[:count_only]
      return object.miq_alerts.count
    else
      return object.miq_alerts.sort_by { |a| a.description.downcase }
    end
  end

  def x_get_tree_pp_kids(object, options)
    if options[:count_only]
      return object.miq_policies.count
    else
      return object.miq_policies.sort_by { |a| a.towhat + a.mode + a.description.downcase }
    end
  end

  def x_get_tree_p_kids(object, options)
    if options[:count_only]
      return object.conditions.count + object.miq_events.count
    else
      return object.conditions.sort_by { |a| a.description.downcase } +
              object.miq_events.sort_by { |a| a.description.downcase }
    end
  end

  def x_get_tree_ev_kids(object, options)
    #if opening Event node in tree, need to use id of policy node from params[:id]
    if (!params[:id] || params[:button]) && options[:tree] == :policy_profile_tree
      id = options[:parent_id].split('-')[2].split('_').first
    elsif (!params[:id] || params[:button]) && options[:tree] == :policy_tree
      id = options[:parent_id].split('-')[4].split('_').first
    else
      nodes = params[:id] && !params[:button] && !params[:pressed] ? params[:id].split("_") : options[:parent_id].split("-")
      if nodes.length == 5
        #when condition delete is pressed in pol tree
        id = nodes.last
      elsif nodes.length == 4
        id = nodes[2].split('-').last
      elsif nodes.length == 3
        id = options[:tree] == :policy_tree ? nodes.last.split('-').last : nodes[1].split('-').last
        #id = options[:tree] == :policy_tree ? nodes.last.split('-').last : nodes[1].split('_').first
      elsif nodes.length == 2
        id = nodes[1].split('-').last
      else
        #if policy copy button was pressed
        id = params[:id]
      end
    end
    pol_rec = MiqPolicy.find_by_id(from_cid(id))  # Get the parent policy record
    items1 = pol_rec ? pol_rec.actions_for_event(object, :success) : []
    items2 = pol_rec ? pol_rec.actions_for_event(object, :failure) : []
    if options[:count_only]
      return items1.count + items2.count
    else
      return items1 + items2
    end
  end

  def x_get_tree_dialog_kids(object, options)
    if options[:count_only]
      return options[:type] == :dialogs ? 0 : object.dialog_resources.count
    else
      return options[:type] == :dialogs ? [] : object.ordered_dialog_resources.collect(&:resource).compact
    end
  end

  def x_get_tree_dialog_tab_kids(object, options)
    if options[:count_only]
      return object.dialog_resources.count
    else
      return object.ordered_dialog_resources.collect(&:resource).compact
    end
  end

  def x_get_tree_dialog_group_kids(object, options)
    if options[:count_only]
      return object.dialog_resources.count
    else
      return object.ordered_dialog_resources.collect(&:resource).compact
    end
  end

  def x_get_tree_st_kids(object, options)
    #if options[:count_only]
    #  return options[:type] = :svccat ? 0 : (object.vms_and_templates.count + object.service_templates.count)
    #else
    #  return options[:type] = :svccat ? [] : (object.vms_and_templates.sort_by { |v| v.name.downcase } +
    #      object.service_templates.sort_by { |st| st.name.downcase })
    #end
    if options[:count_only]
      if options[:type] == :svccat
        return 0
      else
        count = object.custom_button_sets.count + object.custom_buttons.count
        return count
      end
    else
      if options[:type] == :svccat
        return []
      else
        count = object.custom_button_sets.count + object.custom_buttons.count
        if count > 0
          objects =
              [
                  {:id=>object.id.to_s, :text=>"Actions", :image=>"folder", :tip=>"Actions"}
              ]
          return objects
        else
          return []
        end
      end
    end
  end

  def x_get_tree_sr_kids(object, options)
    if options[:count_only]
      typ = object.resource_type
      rec = ServiceTemplate.find_by_id(object.resource_id) if typ == "ServiceTemplate"
      return typ == "ServiceTemplate" ? rec.service_resources.count : 0
    else
      typ = object.resource_type
      rec = ServiceTemplate.find_by_id(object.resource_id) if typ == "ServiceTemplate"
      return (rec.service_resources.sort_by { |a| a.resource_name.downcase })
    end
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    count_only = options[:count_only]
    case options[:type]
    when :ab
      nodes = object[:id].split('_')
      objects = CustomButtonSet.find_all_by_class_name(nodes[1])
      #add as first element of array
      objects.unshift(CustomButtonSet.new(:name=>"[Unassigned Buttons]|ub-#{nodes[1]}",:description=>"[Unassigned Buttons]"))
      return count_only ? objects.length : objects
    when :alert_profile
      # Add all alert profiles so links back from Alerts etc will work - TODO: figure out how to load on demand
      objects = MiqAlertSet.where(:mode => object[:id].split('-')).order("lower(description) ASC")
      if options[:count_only]
        return objects.count
      else
        return objects
      end
    when :db
      if object[:id].split('-').first == "g"
        objects = MiqGroup.all
        return options[:count_only] ? objects.count : objects.sort_by(&:name)
      else
        options[:count_only] ? 0 : []
      end
    when :condition
      nodes = object[:id].split('-')
      if ["host","vm"].include?(nodes.first) && nodes.length == 1
        objects = Condition.where(:towhat => nodes.first.titleize).sort_by { |a| a.description.downcase }
      end
      if options[:count_only]
        return objects.count
      else
        return objects
      end
    when :policy
      nodes = object[:id].split('_')
      if ["compliance","control"].include?(nodes.first) && nodes.length == 1
        # Push folder node ids onto open_nodes array
        ["xx-#{nodes.first}_xx-#{nodes.first}-host", "xx-#{nodes.first}_xx-#{nodes.first}-vm"].each do |n|
          x_tree(options[:tree])[:open_nodes].push(n) unless x_tree(options[:tree])[:open_nodes].include?(n)
        end
        objects = Array.new
        objects.push({:id=>"#{nodes[0]}-host", :text=>"Host #{nodes[0].capitalize} Policies", :image=>"host", :tip=>"Host Policies"})
        objects.push({:id=>"#{nodes[0]}-vm", :text=>"Vm #{nodes[0].capitalize} Policies", :image=>"vm", :tip=>"Vm Policies"})
      elsif %w(host vm).include?(nodes[0].split("-").last)
        # Add all policies so links back from Conditions etc will work - TODO: figure out how to load on demand
        objects = MiqPolicy.where(
                    :mode   => nodes[0].split("-").first.downcase,
                    :towhat => nodes[0].split("-").last.titleize,
                  ).order("lower(description) ASC")
      end
      if options[:count_only]
        return objects.count
      else
        return objects
      end
    when :old_dialogs # VMs & Templates tree has orphaned and archived nodes
      objects = MiqDialog.find_all_by_dialog_type(object[:id].split('_').last).sort_by { |a| a.description.downcase }
      return count_only ? objects.length : objects
    when :reports
      objects = Array.new
      nodes = object[:full_id] ? object[:full_id].split('-') : object[:id].to_s.split('-')
      if nodes.length == 1 #&& nodes.last.split('-').length <= 2 #|| nodes.length == 2
        @sb[:rpt_menu][nodes.last.to_i][1].each_with_index do |r,i|
          objects.push({:id=>"#{nodes.last.split('-').last}-#{i}", :text=>r[0], :image=>"#{@sb[:grp_title] == @sb[:rpt_menu][nodes.last.to_i][0] ? "blue_folder" : "folder"}", :tip=>r[0]})
        end
      elsif nodes.length >= 2 #|| (object[:full_id] && object[:full_id].split('_').length == 2)
        el1 = nodes.length == 2 ?
              nodes[0].split('_').first.to_i : nodes[1].split('_').first.to_i
        @sb[:rpt_menu][el1][1][nodes.last.to_i][1].each_with_index do |r,i|
          report = MiqReport.find_by_name(r)
          objects.push(report) if report
          # break after adding 1 report for a count_only,
          # don't need to go thru them all to determine if node has children
          break if options[:count_only]
        end
      end
      return options[:count_only] ? objects.count : objects
    when :savedreports
      view, pages = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(from_cid(object[:id].split('-').last)), :all_pages=>true)
      objects = Array.new
      view.table.data.each do |s|
        objects.push(MiqReportResult.find_by_id(s["id"]))
      end
      return options[:count_only] ? objects.count : objects.sort_by(&:name)
    when :vandt # VMs & Templates tree has orphaned and archived nodes
      case object[:id]
      when "orph" # Orphaned
        objects = rbac_filtered_objects(ManageIQ::Providers::InfraManager::Vm.all_orphaned) +
            rbac_filtered_objects(ManageIQ::Providers::InfraManager::Template.all_orphaned)
      when "arch" # Archived
        objects = rbac_filtered_objects(ManageIQ::Providers::InfraManager::Vm.all_archived) +
            rbac_filtered_objects(ManageIQ::Providers::InfraManager::Template.all_archived)
      end
      options[:count_only] ? objects.length : objects.sort_by { |a| a.name.downcase }
    when :images # Images by Provider tree has orphaned and archived nodes
      # FIXME: orphaned, archived
      case object[:id]
        when "orph" # Orphaned
          objects = rbac_filtered_objects(ManageIQ::Providers::CloudManager::Template.all_orphaned).sort_by { |a| a.name.downcase }
        when "arch" # Archived
          objects = rbac_filtered_objects(ManageIQ::Providers::CloudManager::Template.all_archived).sort_by { |a| a.name.downcase }
      end
      return options[:count_only] ? objects.length : objects
    when :instances # Instances by Provider tree has orphaned and archived nodes
      # FIXME: orphaned, archived
      case object[:id]
        when "orph" # Orphaned
          objects = rbac_filtered_objects(ManageIQ::Providers::CloudManager::Vm.all_orphaned).sort_by { |a| a.name.downcase }
        when "arch" # Archived
          objects = rbac_filtered_objects(ManageIQ::Providers::CloudManager::Vm.all_archived).sort_by { |a| a.name.downcase }
      end
      return options[:count_only] ? objects.length : objects
    when :filter  # Filter trees have global and my filter nodes
      # FIXME: filter vms_filter templater_filter
      objects = MiqSearch.where(:db => options[:leaf])
      case object[:id]
      when "global" # Global filters
        objects = objects.where("search_type=? or (search_type=? and (search_key is null or search_key<>?))", "global", "default", "_hidden_")
      when "my"     # My filters
        objects = objects.where(:search_type => "user", :search_key => session[:userid])
      end
      return options[:count_only] ? objects.count : objects.sort_by { |a| a.description.downcase }
    when :bottlenecks, :utilization
      nodes = object[:id].split('_')
      emses = Array.new
      storages = Array.new
      if (nodes.length > 1 && nodes[1] == "e") || (object[:full_id] && object[:full_id].split('_')[1] == "e")
        rec = MiqRegion.find_by_id(from_cid(nodes.last.split('-').last))
        emses = rbac_filtered_objects(rec.ems_infras)
      elsif (nodes.length > 1 && nodes[1] == "ds") || (object[:full_id] && object[:full_id].split('_')[1] == "ds")
        rec = MiqRegion.find_by_id(from_cid(nodes.last.split('-').last))
        storages = rbac_filtered_objects(rec.storages)
      elsif (nodes.length > 1 && nodes[1] == "c") || (object[:full_id] && object[:full_id].split('_')[1] == "c")
        rec = ExtManagementSystem.find_by_id(from_cid(nodes.last.split('-').last))
        ems_clusters        = rbac_filtered_objects(rec.ems_clusters)
        non_clustered_hosts = rbac_filtered_objects(rec.non_clustered_hosts)
        if options[:count_only]
          return ems_clusters.count + non_clustered_hosts.count
        else
          return ems_clusters.sort_by { |a| a.name.downcase } + non_clustered_hosts.sort_by { |a| a.name.downcase }
        end
      end
      if options[:count_only]
        return emses.count + storages.count
      else
        return emses.sort_by { |a| a.name.downcase } + storages.sort_by { |a| a.name.downcase }
      end
    when :widgets
      objects = MiqWidget.find_all_by_content_type(WIDGET_CONTENT_TYPE[object[:id].split('-').last])
      return options[:count_only] ? objects.count : objects.sort_by(&:title)
    else
      return options[:count_only] ? 0 : []
    end
  end

  def rbac_filtered_objects(objects, options = {})
    TreeBuilder.rbac_filtered_objects(objects, options)
  end

  # FIXME: move partly to Tree once Trees are made from TreeBuilder
  def valid_active_node(treenodeid)
    modelname, rec_id, nodetype = TreeBuilder.extract_node_model_and_id(treenodeid)
    return treenodeid if ["root",""].include?(nodetype) #incase node is root or doesn't have a prefix
    raise _("No Class found for explorer tree node id '%s'") % treenodeid if modelname.nil?
    kls = modelname.constantize
    return treenodeid if kls == Hash

    unless kls.where(:id => from_cid(rec_id)).exists?
      @replace_trees = [@sb[:active_accord]] # refresh trees
      self.x_node = "root"
      add_flash(_("Last selected %s no longer exists") % ui_lookup(:model => kls.to_s), :error)
    end
    x_node
  end
end
