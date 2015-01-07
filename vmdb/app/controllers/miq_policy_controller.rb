class MiqPolicyController < ApplicationController
  include_concern 'MiqActions'
  include_concern 'AlertProfiles'
  include_concern 'Alerts'
  include_concern 'Conditions'
  include_concern 'Events'
  include_concern 'Policies'
  include_concern 'PolicyProfiles'
  include_concern 'Rsop'

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'explorer'
  end

  def export
    @breadcrumbs = Array.new
    @layout = "miq_policy_export"
    drop_breadcrumb( {:name=>"Import / Export", :url=>"miq_policy/export"} )
    case params[:button]
    when "cancel"
      @sb = nil
      if @lastaction != "fetch_yaml"
        add_flash(_("%s cancelled by user") % "Export")
      end
      render :update do |page|                    # Use JS to update the display
        page.redirect_to :action=>"explorer"
      end
    when "export"
      if params[:choices_chosen]
        @sb[:new][:choices_chosen] = params[:choices_chosen]
      else
        @sb[:new][:choices_chosen] = Array.new
      end
      if @sb[:new][:choices_chosen].length == 0 # At least one member is required
        add_flash(_("At least %{num} %{model} must be selected for %{action}") % {:num=>1, :model=>"item", :action=>"export"}, :error)
        render :update do |page|                    # Use JS to update the display
          page.replace_html("profile_export_div", :partial=>"export")
          page << "miqSparkle(false);"
        end
      else
        begin
          case @sb[:dbtype]
            when "pp"
              db = MiqPolicySet
              filename = "Profiles"
            when "p"
              db = MiqPolicy
              filename = "Policies"
            when "al"
              db = MiqAlert
              filename = "Alerts"
          end
          session[:export_data] = MiqPolicy.export_to_yaml(@sb[:new][:choices_chosen], db)
          render :update do |page|          # Use RJS to update the display
            page.redirect_to :action=>'fetch_yaml', :fname=>filename, :escape=>false
          end
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") % "export" << bang.message, :error)
          render :update do |page|                    # Use JS to update the display
            page.replace_html("profile_export_div", :partial=>"export")
            page << "miqSparkle(false);"
          end
        end
      end
    when "reset", nil # Reset or first time in
      dbtype = params[:dbtype] == nil ? "pp" : params[:dbtype]
      type = params[:typ] == nil ? "export" : params[:typ]

      export_chooser(dbtype,type)
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    if params[:pressed] == "refresh_log"
      refresh_log
      return
    end
    if params[:pressed] == "collect_logs"
      collect_logs
      return
    end

    if ! @refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
  end

  POLICY_X_BUTTON_ALLOWED_ACTIONS = {
    'action_delete'           => :action_delete,
    'action_edit'             => :action_edit,
    'action_new'              => :action_edit,
    'alert_delete'            => :alert_delete,
    'alert_edit'              => :alert_edit,
    'alert_copy'              => :alert_edit,
    'alert_new'               => :alert_edit,
    'alert_profile_assign'    => :alert_profile_assign,
    'alert_profile_delete'    => :alert_profile_delete,
    'alert_profile_edit'      => :alert_profile_edit,
    'alert_profile_new'       => :alert_profile_edit,
    'condition_delete'        => :condition_delete,
    'condition_edit'          => :condition_edit,
    'condition_copy'          => :condition_edit,
    'condition_policy_copy'   => :condition_edit,
    'condition_new'           => :condition_edit,
    'condition_remove'        => :condition_remove,
    'event_edit'              => :event_edit,
    'profile_delete'          => :profile_delete,
    'profile_edit'            => :profile_edit,
    'profile_new'             => :profile_edit,
    'policy_copy'             => :policy_copy,
    'policy_delete'           => :policy_delete,
    'policy_edit'             => :policy_edit,
    'policy_new'              => :policy_edit,
    'policy_edit_conditions'  => :policy_edit,
    'policy_edit_events'      => :policy_edit,
  }.freeze

  def x_button
    action = params[:pressed]

    raise ActionController::RoutingError.new('invalid button action') unless
      POLICY_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    self.send(POLICY_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  # Send the zipped up logs and zip files
  def fetch_yaml
    @lastaction = "fetch_yaml"
    file_name = "#{params[:fname]}_#{format_timezone(Time.now,Time.zone,"export_filename")}.yaml"
    disable_client_cache
    send_data(session[:export_data], :filename =>file_name)
    session[:export_data] = nil
  end

  def upload
    redirect_options = {:action => 'import', :dbtype => params[:dbtype]}

    @sb[:conflict] = false
    if upload_file_valid?
      begin
        import_file_upload = miq_policy_import_service.store_for_import(params[:upload][:file])
        @sb[:hide] = true

        redirect_options.merge!(:import_file_upload_id => import_file_upload.id)
      rescue => err
        redirect_options.merge!(:flash_msg => _("Error during '%s': ") %  "Policy Import" + err.message,
                                :flash_error => true,
                                :action => "export")
      end
    else
      redirect_options.merge!(:flash_msg => _("Use the Browse button to locate an Import file"),
                              :flash_error => true,
                              :action => "export")
    end

    redirect_to redirect_options
  end

  def get_json
    import_file_upload = ImportFileUpload.find(params[:import_file_upload_id])
    policy_import_json = import_as_json(import_file_upload.policy_import_data)

    respond_to do |format|
      format.json { render :json => policy_import_json }
    end
  end

  def import
    @breadcrumbs = []
    @layout = "miq_policy_export"
    @import_file_upload_id = params[:import_file_upload_id]
    drop_breadcrumb( {:name=>"Import / Export", :url=>"miq_policy/export"} )

    if params[:commit] == "import"
      begin
        miq_policy_import_service.import_policy(@import_file_upload_id)
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "upload" << bang.message, :error)
      else
        @sb[:hide] = false
        add_flash(_("Import file was uploaded successfully"))
      end

      render :update do |page|
        page.replace_html("profile_export_div", :partial=>"export")
        page << "miqSparkle(false);"
      end
    elsif params[:commit] == "cancel"
      miq_policy_import_service.cancel_import(params[:import_file_upload_id])

      render :update do |page|
        page.redirect_to :action => 'export', :flash_msg=>_("%s cancelled by user") % "Import"
      end

    #init import
    else
      if @sb[:conflict]
        add_flash(_("Import not available due to conflicts"),:error)
      else
        add_flash(_("Press commit to Import")) if !@flash_array
      end
      render :action=>"import", :layout=> true
    end
  end

  def export_field_changed
    prev_dbtype = @sb[:dbtype]
    export_chooser(params[:dbtype],"export") if params[:dbtype]
    if params[:choices_chosen]
      @sb[:new][:choices_chosen] = params[:choices_chosen]
    else
      @sb[:new][:choices_chosen] = Array.new
    end
    render :update do |page|                    # Use JS to update the display
      if prev_dbtype != @sb[:dbtype]    # If any export db type has changed
      # page.redirect_to :action=>"export", :dbtype=>params[:dbtype], :typ=>"export"
        page.replace_html("profile_export_div", :partial=>"export")
      end
    end
  end

  # Show/Unshow out of scope items
  def policy_options
    @record = identify_record(params[:id])
    @policy_options ||= Hash.new
    @policy_options[:out_of_scope] = (params[:out_of_scope] == "1")
    build_policy_tree(@polArr)
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "#{session[:tree_name]}.saveOpenStates('#{session[:tree_name]}','path=/');"
      page << "#{session[:tree_name]}.loadOpenStates('#{session[:tree_name]}');"
      page.replace("main_div", :partial=>"vm/policies")
    end
  end

  def explorer
    @breadcrumbs = []
    @explorer = true
    session[:export_data] = nil
    @sb[:open_tree_nodes] ||= [] # Create array to keep open tree nodes (only for autoload trees)
    self.x_active_tree   ||= 'policy_profile_tree'
    self.x_active_accord ||= 'policy_profile'

    @trees   = []
    @accords = []

    profile_build_tree
    @trees.push("profile_tree")
    @accords.push(:name => "policy_profile", :title => "Policy Profiles", :container => "policy_profile_tree_div", :image => "policy_profile")

    policy_build_tree
    @trees.push("policy_tree")
    @accords.push(:name => "policy", :title => "Policies", :container => "policy_tree_div", :image => "miq_policy")

    event_build_tree
    @trees.push("event_tree")
    @accords.push(:name => "event", :title => "Events", :container => "event_tree_div", :image => "miq_event")

    condition_build_tree
    @trees.push("condition_tree")
    @accords.push(:name => "condition", :title => "Conditions", :container => "condition_tree_div", :image => "miq_condition")

    action_build_tree
    @trees.push("action_tree")
    @accords.push(:name => "action", :title => "Actions", :container => "action_tree_div", :image => "miq_action")

    alert_profile_build_tree
    @trees.push("alert_profile_tree")
    @accords.push(:name => "alert_profile", :title => "Alert Profiles", :container => "alert_profile_tree_div", :image => "miq_alert_profile")

    alert_build_tree
    @trees.push("alert_tree")
    @accords.push(:name => "alert", :title => "Alerts", :container => "alert_tree_div", :image => "miq_alert")

    if params[:profile].present?  # If profile record id passed in, position on that node
      self.x_active_tree = 'policy_profile_tree'
      profile_id = params[:profile].to_i
      if MiqPolicySet.exists?(:id => profile_id)
        self.x_node = "pp_#{profile_id}"
      else
        add_flash(_("%s no longer exists") %  ui_lookup(:model => "MiqPolicySet"), :error)
        self.x_node = "root"
      end
    end
    get_node_info(x_node)

    render :layout => "explorer"
  end

  # Item clicked on in the explorer right cell
  def x_show
    @explorer = true
    tree_select
  end

  def accordion_select
    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"
    get_node_info(x_node)
    replace_right_cell(@nodetype)
  end

  def tree_select
    #set these when a link on one of the summary screen was pressed
    self.x_active_accord = params[:accord]           if params[:accord]
    self.x_active_tree   = "#{params[:accord]}_tree" if params[:accord]
    self.x_active_tree   = params[:tree] if params[:tree]
    self.x_node          = params[:id]
    get_node_info(x_node)
    replace_right_cell(@nodetype)
  end

  def cat_pressed
    @cat_selected = params[:id].split(':')[1] + ": " + params[:id].split(':')[2]
    temp_tagname = params[:id].split(':')[0]
    @tag_name = temp_tagname.split('__')[1]
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use RJS to update the display
      page.replace("form_options_div", :partial=>"form_options")
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
    end
  end

  def search
    get_node_info(x_node)
    case x_active_tree
    when "profile", "event", "action", "alert"
      replace_right_cell(x_node)
    when "policy", "condition", "alert_profile"
      replace_right_cell("xx")
    end
  end

  def log
    @breadcrumbs = Array.new
    @log = $policy_log.contents(nil,1000)
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
    @lastaction = "policy_logs"
    @layout = "miq_policy_logs"
    @msg_title = "Policy"
    @download_action = "fetch_log"
    @server_options ||= Hash.new
    @server_options[:server_id] ||= MiqServer.my_server.id
    @temp[:server] = MiqServer.my_server
    drop_breadcrumb( {:name=>"Log", :url=>"/miq_ae_policy/log"} )
    render :action=>"show"
  end

  def refresh_log
    @log = $policy_log.contents(nil,1000)
    @temp[:server] = MiqServer.my_server
    add_flash(_("Logs for this CFME Server are not available for viewing"), :warning)  if @log.blank?
    render :update do |page|                    # Use JS to update the display
      page.replace_html("main_div", :partial=>"layouts/log_viewer")
    end
  end

  # Send the log in text format
  def fetch_log
    disable_client_cache
    send_data($policy_log.contents(nil,nil),
      :filename => "policy.log" )
    AuditEvent.success(:userid=>session[:userid],:event=>"download_policy_log",:message=>"Policy log downloaded")
  end

  private

  def import_as_json(yaml_array)
    iterate_status(yaml_array) if yaml_array
  end

  def iterate_status(items = nil, result = [], parent_id = nil, indent = nil)
    items.each do |item|
      entry = { "id"     => result.count.to_s,
                "title"  => "<b>#{I18n.t("model_name.#{item[:class].underscore}")}:</b>" +
                             " #{item[:description]}",
                "parent" => parent_id,
                "status_icon" => get_status_icon(item[:status]),
                "indent" => (indent.nil? ? 0 : indent + 1)}

      entry["_collapsed"] = false if item[:children]

      if item[:messages]
        entry["msg"] = ""
        messages = item[:messages]

        if messages.count > 1
          messages.each {|msg| entry["msg"] += msg + ', '}
        else
          messages.each {|msg| entry["msg"] += msg}
        end

        @sb[:conflict] = true
      end

      result << entry

      # recursive call if item have the childrens
      if item[:children]
        iterate_status(item[:children], result, result.count - 1, result.last["indent"])
      end
    end

    result.to_json
  end

  def get_status_icon(status)
    icon = case status
      when :update then "checkmark"
      when :add then "equal-green"
      when :conflict then "x"
    end

    "/images/icons/16/#{icon}.png"
  end

  def miq_policy_import_service
    @miq_policy_import_service ||= MiqPolicyImportService.new
  end

  def upload_file_valid?
    params.fetch_path(:upload, :file).respond_to?(:read)
  end

  def peca_get_all(what, get_view)
    @no_checkboxes       = true
    @showlinks           = true
    @lastaction          = "#{what}_get_all"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    sortcol_key = "#{what}_sortcol".to_sym
    sortdir_key = "#{what}_sortdir".to_sym
    @sortcol    = (session[sortcol_key] || 0).to_i
    @sortdir    =  session[sortdir_key] || 'ASC'
    set_search_text
    @_params[:search_text] = @search_text if @search_text && @_params[:search_text]             #Added to pass search text to get_view method
    @view, @pages            = get_view.call # Get the records (into a view) and the paginator
    @current_page            = @pages[:current] if @pages != nil  # save the current page number
    session[sortcol_key]     = @sortcol
    session[sortdir_key]     = @sortdir

    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial => "layouts/gtl", :locals => { :action_url=>"#{what}_get_all",:button_div=>'policy_bar' } )
      end
    end

    @sb[:tree_typ]   = what.pluralize
    @right_cell_text = _("All %s") % what.pluralize.titleize
    @right_cell_div  = "#{what}_list"
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    @nodetype, nodeid = valid_active_node(treenodeid).split("_").last.split("-")
    node_ids = Hash.new
    treenodeid.split("_").each do |p|
      node_ids[p.split("-").first] = p.split("-").last  # Create a hash of all record ids represented by the selected tree node
    end
    @sb[:node_ids] ||= Hash.new
    @sb[:node_ids][x_active_tree] = node_ids
    get_root_node_info  if x_node == "root"                     # Get node info of tree roots
    folder_get_info(treenodeid) if treenodeid != "root"         # Get folder info for all node types
    case @nodetype
    when "pp" # Policy Profile
      profile_get_info(MiqPolicySet.find(from_cid(nodeid)))
    when "p"  # Policy
      policy_get_info(MiqPolicy.find(from_cid(nodeid)))
    when "co" # Condition
      condition_get_info(Condition.find(from_cid(nodeid)))
    when "ev" # Event
      event_get_info(MiqEvent.find(from_cid(nodeid)))
    when "a","ta","fa"  # Action or True/False Action
      action_get_info(MiqAction.find(from_cid(nodeid)))
    when "ap" # Alert Profile
      alert_profile_get_info(MiqAlertSet.find(from_cid(nodeid)))
    when "al" # Alert
      alert_get_info(MiqAlert.find(from_cid(nodeid)))
    end
    @show_adv_search = (@nodetype == "xx" && !@folders) || (@nodetype == "root" && ![:alert_profile_tree,:condition_tree,:policy_tree].include?(x_active_tree))
    x_history_add_item(:id=>treenodeid, :text=>@right_cell_text)
  end

  # Fetches right side info if a tree root is selected
  def get_root_node_info
    case x_active_tree
    when :policy_profile_tree
      profile_get_all
    when :policy_tree
      policy_get_all_folders
    when :event_tree
      event_get_all
    when :condition_tree
      condition_get_all_folders
    when :action_tree
      action_get_all
    when :alert_profile_tree
#     alert_profile_get_all
      alert_profile_get_all_folders
    when :alert_tree
      alert_get_all
    end
  end

  # Check for parent nodes missing from vandt tree and return them if any
  def open_parent_nodes
    existing_node = nil                     # Init var
    nodes = params[:id].split('_')
    nodes.pop
    parents = Array.new
    nodes.each do |node|
      parents.push({:id=>node.split('xx-').last})
    end

    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    unless parents.empty? ||  # Skip if no parents or parent already open
        x_tree[:open_nodes].include?(x_build_node_id(parents.last))
      parents.reverse.each do |p|
        p_node = x_build_node_id(p)
        # some of the folder nodes are not autoloaded
        # that's why they already exist in open_nodes
        x_tree[:open_nodes].push(p_node) unless x_tree[:open_nodes].include?(p_node)
        existing_node = p_node
      end
    end

    add_nodes = tree_add_child_nodes(existing_node) if existing_node # Build the new nodes hash
    self.x_node = params[:id]
    return add_nodes
  end

  def replace_right_cell(nodetype, replace_trees = [])  # replace_trees can be an array of tree symbols to be replaced
    replace_trees = @replace_trees if @replace_trees  #get_node_info might set this
    @explorer = true

    # Build the JSON objects in @temp for trees to be replaced
    if replace_trees
      profile_build_tree        if replace_trees.include?(:policy_profile)
      policy_build_tree         if replace_trees.include?(:policy)
      event_build_tree          if replace_trees.include?(:event)
      condition_build_tree      if replace_trees.include?(:condition)
      action_build_tree         if replace_trees.include?(:action)
      alert_profile_build_tree  if replace_trees.include?(:alert_profile)
      alert_build_tree          if replace_trees.include?(:alert)
    end

    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    h_buttons, h_xml = build_toolbar_buttons_and_xml('x_history_tb')

    # Build a presenter to render the JS
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :temp        => @temp,
    )
    r = proc { |opts| render_to_string(opts) }

    presenter[:open_accord] = params[:accord] if params[:accord] # Open new accordion

    #js_options[:add_nodes] = add_nodes  # Update the tree with any new nodes

    # With dynatree, simply replace the tree partials to reload the trees
    replace_trees.each do |t|
      case t
      when :policy_profile
        self.x_node = @new_profile_node if @new_profile_node
        presenter[:replace_partials][:policy_profile_tree_div] = r[:partial => "profile_tree"]
      when :policy
        presenter[:replace_partials][:policy_tree_div] = r[:partial => "policy_tree"]
      when :event
        presenter[:replace_partials][:event_tree_div] = r[:partial => "event_tree"]
      when :condition
        self.x_node = @new_condition_node if @new_condition_node
        presenter[:replace_partials][:condition_tree_div] = r[:partial => "condition_tree"]
      when :action
        self.x_node = @new_action_node if @new_action_node
        presenter[:replace_partials][:action_tree_div] = r[:partial => "action_tree"]
      when :alert_profile
        self.x_node = @new_alert_profile_node if @new_alert_profile_node
        presenter[:replace_partials][:alert_profile_tree_div] = r[:partial => "alert_profile_tree"]
        # Send down extra alert_profile tree if present
        if @assign && @assign[:object_tree]
          presenter[:object_tree_json] = @assign[:object_tree]
        end
      when :alert
        self.x_node = @new_alert_node if @new_alert_node
        presenter[:replace_partials][:alert_tree_div] = r[:partial => "alert_tree"]
      end
    end

    if params[:action].ends_with?('_delete') &&
        !x_node.starts_with?('p') &&
        !x_node.starts_with?('co')
      nodes = x_node.split('_')
      nodes.pop
      self.x_node = nodes.join("_")
    end
    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    @changed = session[:changed] if @edit   # to get save/reset buttons to highlight when fields are moved left/right
    edit_str = @edit ? 'editing_' : ''

    # Replace right side with based on selected tree node type
    case nodetype
    when 'root'
      partial_name, model =
      case x_active_tree
      when :policy_profile_tree then ['profile_list',          ui_lookup(:models=>'MiqPolicySet')]
      when :policy_tree         then ['policy_folders',        ui_lookup(:models=>'MiqPolicy')]
      when :event_tree          then ['event_list',            ui_lookup(:tables=>'miq_event')]
      when :condition_tree      then ['condition_folders',     ui_lookup(:models=>'Condition')]
      when :action_tree         then ['action_list',           ui_lookup(:models=>'MiqAction')]
      when :alert_profile_tree  then ['alert_profile_folders', ui_lookup(:models=>'MiqAlertSet')]
      when :alert_tree          then ['alert_list',            ui_lookup(:models=>'MiqAlert')]
      end

      presenter[:update_partials][:main_div] = r[:partial => partial_name]
      right_cell_text = _("All %s") %  model
    when 'pp'
      presenter[:update_partials][:main_div] = r[:partial => 'profile_details']
      right_cell_text =
        if @profile && @profile.id.blank?
          _("Adding a new %s") % ui_lookup(:model=>'MiqPolicySet')
        else
          @edit ? _("Editing %{model} \"%{name}\"") % {:name=>@profile.description.gsub(/'/,"\\'"), :model=>ui_lookup(:model=>"MiqPolicySet")} :
                  _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqPolicySet"), :name=>@profile.description.gsub(/'/,"\\'")}
        end
    when 'xx'
      presenter[:update_partials][:main_div] =
        if @profiles
          r[:partial => 'profile_list']
        elsif @policies || (@view && @sb[:tree_typ] == 'policies')
          right_cell_text = _("All %{typ} %{model}") % {:typ => "#{ui_lookup(:model => @sb[:nodeid])} #{@sb[:mode] ? @sb[:mode].capitalize : ""}", :model => ui_lookup(:models => "MiqPolicy")}
          r[:partial => 'policy_list']
        elsif @conditions
          right_cell_text = _("All %{typ} %{model}") % {:typ => ui_lookup(:model => @sb[:folder].titleize), :model => ui_lookup(:models => 'Condition')}
          r[:partial => 'condition_list']
        elsif @folders
          right_cell_text = _("%{typ} %{model}") % {:typ => ui_lookup(:model => @sb[:folder]), :model => ui_lookup(:models => 'MiqPolicy')}
          r[:partial => 'policy_folders']
        elsif @alert_profiles
          r[:partial => 'alert_profile_list']
        end
    when 'p'
      presenter[:update_partials][:main_div] = r[:partial => 'policy_details', :locals=>{:read_only=>true}]
      if @policy.id.blank?
        right_cell_text = _("Adding a new %s") %  "#{ui_lookup(:model => @sb[:nodeid])} #{@sb[:mode] ? @sb[:mode].capitalize : ""} Policy"
      else
        right_cell_text = @edit ?
            _("Editing %{model} \"%{name}\"") % {:model => "#{ui_lookup(:model => @sb[:nodeid])} #{@sb[:mode] ? @sb[:mode].capitalize : ""} Policy", :name => @policy.description.gsub(/'/,"\\'")} :
            _("%{model} \"%{name}\"") % {:model => "#{ui_lookup(:model => @sb[:nodeid])} #{@sb[:mode] ? @sb[:mode].capitalize : ""} Policy", :name => @policy.description.gsub(/'/,"\\'")}
        right_cell_text += _(" %s Assignments") % ui_lookup(:model=>'Condition') if @edit && @edit[:typ] == 'conditions'
        right_cell_text += _(" %s Assignments") % ui_lookup(:model=>'Event')     if @edit && @edit[:typ] == 'events'
      end
    when 'co'
      # Set the JS types and titles vars if value fields are showing (needed because 2 expression editors are present)
      if @edit && @edit[@expkey]
        set_exp_val = proc do |val|
          if @edit[@expkey][val]  # if an expression with value 1 is showing
            presenter[:exp] = {}
            presenter[:exp]["#{val}_type".to_sym]  = @edit[@expkey][val][:type].to_s if @edit[@expkey][val][:type]
            presenter[:exp]["#{val}_title".to_sym] = @edit[@expkey][val][:title]     if @edit[@expkey][val][:title]
          end
        end
        set_exp_val.call(:val1)
        set_exp_val.call(:val2)
      end
      presenter[:update_partials][:main_div] = r[:partial => 'condition_details', :locals=>{:read_only=>true}]
      right_cell_text = if @condition.id.blank?
        _("Adding a new %s") % ui_lookup(:model=>'Condition')
      else
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name=>@condition.description.gsub(/'/,"\\'"), :model=>"#{ui_lookup(:model=>@edit[:new][:towhat])} Condition"} :
          _("%{model} \"%{name}\"") % {:name=>@condition.description.gsub(/'/,"\\'"), :model=>"#{ui_lookup(:model=>@condition.towhat)} Condition"}
      end
    when 'ev'
      presenter[:update_partials][:main_div] = r[:partial => 'event_details', :locals=>{:read_only=>true}]
      options = {:name => @event.description.gsub(/'/, "\\\\'"), :model => ui_lookup(:table => 'miq_event')}
      right_cell_text = @edit ? _("Editing %{model} \"%{name}\"") % options : _("%{model} \"%{name}\"") % options
    when 'a', 'ta', 'fa'
      presenter[:update_partials][:main_div] = r[:partial => 'action_details', :locals=>{:read_only=>true}]
      right_cell_text = if @action.id.blank?
                          _("Adding a new %s") % ui_lookup(:model => 'MiqAction')
                        else
                          if @edit
                            _("Editing %{model} \"%{name}\"") %
                              {:name  => @action.description.gsub(/'/, "\\\\'"),
                               :model => ui_lookup(:model => 'MiqAction')}
                          else
                            _("%{model} \"%{name}\"") %
                              {:name  => @action.description.gsub(/'/, "\\\\'"),
                               :model => ui_lookup(:model => 'MiqAction')}
                          end
                        end
    when 'ap'
      presenter[:update_partials][:main_div] = r[:partial => 'alert_profile_details', :locals=>{:read_only=>true}]
      right_cell_text = if @alert_profile.id.blank?
        _("Adding a new %s") % ui_lookup(:model=>'MiqAlertSet')
      else
        @edit ? _("Editing %{model} \"%{name}\"") % {:name=>@alert_profile.description.gsub(/'/,"\\'"), :model=>"#{ui_lookup(:model=>@edit[:new][:mode])} #{ui_lookup(:model=>'MiqAlertSet')}"} :
                _("%{model} \"%{name}\"") % {:name=>@alert_profile.description.gsub(/'/,"\\'"), :model=>ui_lookup(:model=>'MiqAlertSet')}
      end
    when 'al'
      presenter[:update_partials][:main_div] = r[:partial => 'alert_details', :locals=>{:read_only=>true}]
      right_cell_text = if @alert.id.blank?
        _("Adding a new %s") % ui_lookup(:model=>'MiqAlert')
      else
        pfx = @assign ? ' assignments for ' : ''
        msg = @edit ? _("Editing %{model} \"%{name}\"") : _("%{model} \"%{name}\"")
        msg % {:name => @alert.description.gsub(/'/, "\\\\'"), :model => "#{pfx} #{ui_lookup(:model => "MiqAlert")}"}
      end
    end
    presenter[:right_cell_text] = right_cell_text

    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons && c_xml

    presenter[:reload_toolbars][:history] = {:buttons => h_buttons, :xml => h_xml} if h_buttons && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons, :xml => c_xml} if c_buttons && c_xml

    if (@edit && @edit[:new]) || @assign
      locals = {
        :action_url => @sb[:action],
        :record_id  => @edit ? @edit[:rec_id] : @assign[:rec_id],
      }
      presenter[:expand_collapse_cells][:a] = 'collapse'
      # If was collapsed for summary screen and there were no records on show_list
      presenter[:expand_collapse_cells][:c] = 'expand'
      presenter[:set_visible_elements][:form_buttons_div] = true
      presenter[:update_partials][:form_buttons_div] = r[:partial => "layouts/x_edit_buttons", :locals => locals]
    else
      # Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
      presenter[:set_visible_elements][:button_on] = false
      presenter[:expand_collapse_cells][:a] = 'expand'
      presenter[:expand_collapse_cells][:c] = 'collapse'
    end

    # Replace the searchbox
    presenter[:replace_partials][:adv_searchbox_div] = r[:partial => 'layouts/x_adv_searchbox', :locals => {:nameonly => true}]

    # Hide/show searchbox depending on if a list is showing
    presenter[:set_visible_elements][:adv_searchbox_div] = @show_adv_search

    presenter[:miq_record_id] = @record.try(:id)

    # Lock current tree if in edit or assign, else unlock all trees
    if @edit || @assign
      presenter[:lock_unlock_trees][x_active_tree] = true
    else
      [:policy_profile_tree, :policy_tree, :condition_tree,
       :action_tree, :alert_profile_tree, :alert_tree].each do |tree|
        presenter[:lock_unlock_trees][tree] = false
      end
    end

    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  def send_button_changes
    if @edit
      @changed = (@edit[:new] != @edit[:current])
    elsif @assign
      @changed = (@assign[:new] != @assign[:current])
    end
    get_tags_tree if @action_type_changed || @snmp_trap_refresh
    render :update do |page|                    # Use JS to update the display
      if @edit
        if @action_type_changed || @snmp_trap_refresh
          page.replace("action_options_div", :partial=>"action_options")
        elsif @alert_refresh
          page.replace("alert_details_div",  :partial=>"alert_details")
        elsif @to_email_refresh
          page.replace("edit_to_email_div",
                        :partial=>"layouts/edit_to_email",
                        :locals=>{:action_url=>"alert_field_changed", :record=>@alert})
        elsif @alert_snmp_refresh
          page.replace("alert_snmp_div", :partial=>"alert_snmp")
        elsif @alert_mgmt_event_refresh
          page.replace("alert_mgmt_event_div", :partial=>"alert_mgmt_event")
        elsif @tag_selected
          page.replace_html("tag_selected", @tag_selected)
        end
      elsif @assign
        if params.has_key?(:chosen_assign_to) || params.has_key?(:chosen_cat)
          page.replace("alert_profile_assign_div", :partial=>"alert_profile_assign")
        end
      end
      page << javascript_for_miq_button_visibility_changed(@changed)
      page << "miqSparkle(false);"
    end
  end

  # Handle the middle buttons on the add/edit forms
  # pass in member list symbols (i.e. :policies)
  def handle_selection_buttons( members,
                                members_chosen = :members_chosen,
                                choices = :choices,
                                choices_chosen = :choices_chosen)
    if params[:button].ends_with?("_left")
      if params[members_chosen] == nil
        add_flash(_("No %s were selected to move left") % members.to_s.split("_").first.titleize, :error)
      else
        if @edit[:event_id]                                           # Handle Actions for an Event
          params[members_chosen].each do |mc|
            idx = nil
            @edit[:new][members].each_with_index {|mem,i| idx = mem[-1] == mc.to_i ? i : idx }  # Find the index of the new members array
            next if idx == nil
            desc = @edit[:new][members][idx][0].slice(4..-1)        # Remove (x) prefix from the chosen item
            @edit[choices][desc] = mc.to_i                          # Add item back into the choices hash
            @edit[:new][members].delete_at(idx)                     # Remove item from the array
          end
        else
          mems = @edit[:new][members].invert
          params[members_chosen].each do |mc|
            @edit[choices][mems[mc.to_i]] = mc.to_i
            @edit[:new][members].delete(mems[mc.to_i])
          end
        end
      end
    elsif params[:button].ends_with?("_right")
      if params[choices_chosen] == nil
        add_flash(_("No %s were selected to move right") % members.to_s.split("_").first.titleize, :error)
      else
        mems = @edit[choices].invert
        if @edit[:event_id]                                           # Handle Actions for an Event
          params[choices_chosen].each do |mc|
            @edit[:new][members].push(["(S) " + mems[mc.to_i], true, mc.to_i])  # Add selection to chosen members array, default to synch = true
            @edit[choices].delete(mems[mc.to_i])                    # Remove from the choices hash
          end
        else
          params[choices_chosen].each do |mc|
            @edit[:new][members][mems[mc.to_i]] = mc.to_i
            @edit[choices].delete(mems[mc.to_i])
          end
        end
      end
    elsif params[:button].ends_with?("_allleft")
      if @edit[:new][members].length == 0
        add_flash(_("No %s were selected to move left") % members.to_s.split("_").first.titleize, :error)
      else
        if @edit[:event_id]                                           # Handle Actions for an Event
          @edit[:new][members].each do |m|
            @edit[choices][m.first.slice(4..-1)] = m.last           # Put description/id of each chosen member back into choices hash
          end
        else
          @edit[:new][members].each do |key, value|
            @edit[choices][key] = value
          end
        end
        @edit[:new][members].clear
      end
    elsif params[:button].ends_with?("_up")
      if params[members_chosen] == nil || params[members_chosen].length != 1
        add_flash(_("Select only one or consecutive %s to move up") % members.to_s.split("_").first.singularize.titleize, :error)
      else
        if params[:button].starts_with?("true")
          @true_selected = params[members_chosen][0].to_i
        else
          @false_selected = params[members_chosen][0].to_i
        end
        idx = nil
        mc = params[members_chosen][0]
        @edit[:new][members].each_with_index {|mem,i| idx = mem[-1] == mc.to_i ? i : idx }  # Find item index in new members array
        return if idx == nil || idx == 0
        pulled = @edit[:new][members].delete_at(idx)
        @edit[:new][members].insert(idx - 1, pulled)
      end
    elsif params[:button].ends_with?("_down")
      if params[members_chosen] == nil || params[members_chosen].length != 1
        add_flash(_("Select only one or consecutive %s to move down") % members.to_s.split("_").first.singularize.titleize, :error)
      else
        if params[:button].starts_with?("true")
          @true_selected = params[members_chosen][0].to_i
        else
          @false_selected = params[members_chosen][0].to_i
        end
        idx = nil
        mc = params[members_chosen][0]
        @edit[:new][members].each_with_index {|mem,i| idx = mem[-1] == mc.to_i ? i : idx }  # Find item index in new members array
        return if idx == nil || idx >= @edit[:new][members].length - 1
        pulled = @edit[:new][members].delete_at(idx)
        @edit[:new][members].insert(idx + 1, pulled)
      end
    elsif params[:button].ends_with?("_sync")
      if params[members_chosen] == nil
        add_flash(_("No %s selected to set to Synchronous") % members.to_s.split("_").first.titleize, :error)
      else
        if params[:button].starts_with?("true")
          @true_selected = params[members_chosen][0].to_i
        else
          @false_selected = params[members_chosen][0].to_i
        end
        params[members_chosen].each do |mc|
          idx = nil
          @edit[:new][members].each_with_index {|mem,i| idx = mem[-1] == mc.to_i ? i : idx }  # Find the index in the new members array
          next if idx == nil
          @edit[:new][members][idx][0] = "(S) " + @edit[:new][members][idx][0].slice(4..-1)   # Change prefix to (S)
          @edit[:new][members][idx][1] = true                     # Set synch to true
        end
      end
    elsif params[:button].ends_with?("_async")
      if params[members_chosen] == nil
        add_flash(_("No %s selected to set to Asynchronous") % members.to_s.split("_").first.titleize, :error)
      else
        if params[:button].starts_with?("true")
          @true_selected = params[members_chosen][0].to_i
        else
          @false_selected = params[members_chosen][0].to_i
        end
        params[members_chosen].each do |mc|
          idx = nil
          @edit[:new][members].each_with_index {|mem,i| idx = mem[-1] == mc.to_i ? i : idx }  # Find the index in the new members array
          next if idx == nil
          @edit[:new][members][idx][0] = "(A) " + @edit[:new][members][idx][0].slice(4..-1)   # Change prefix to (A)
          @edit[:new][members][idx][1] = false                    # Set synch to false
        end
      end
    end
  end

  def apply_search_filter(search_str,results)
    if search_str.first == "*"
      results.delete_if{|r|!r.description.downcase.ends_with?(search_str[1..-1].downcase)}
    elsif search_str.last == "*"
      results.delete_if{|r|!r.description.downcase.starts_with?(search_str[0..-2].downcase)}
    else
      results.delete_if{|r|!r.description.downcase.include?(search_str.downcase)}
    end
  end

  def set_search_text
    @sb[:pol_search_text] ||= Hash.new
    if params[:search_text]
      @search_text = params[:search_text].strip
      @sb[:pol_search_text][x_active_tree] = @search_text if !@search_text.nil?
    else
      @search_text = @sb[:pol_search_text][x_active_tree]
    end
  end

  # Get list of folder contents
  def folder_get_info(folder_node)
    nodetype, nodeid = folder_node.split("_")
    @sb[:mode] = nil
    @sb[:nodeid] = nil
    @sb[:folder] = nodeid.nil? ? nodetype.split("-").last : nodeid
    if x_active_tree == :policy_tree
      if nodeid.nil? && ["compliance","control"].include?(nodetype.split('-').last)
        @folders = ["Host #{nodetype.split('-').last.titleize}", "Vm #{nodetype.split('-').last.titleize}"]
        @right_cell_text = _("%{typ} %{model}") % {:typ=>nodetype.split('-').last.titleize, :model=>ui_lookup(:models=>"MiqPolicy")}
      else
        @sb[:mode] = nodeid.split("-")[1]
        @sb[:nodeid] = nodeid.split("-").last
        @sb[:folder] = "#{nodeid.split("-")[1]}-#{nodeid.split("-")[2]}"
        set_search_text
        policy_get_all if folder_node.split("_").length <= 2
        @right_cell_text = _("All %{typ} %{model}") % {:typ=>ui_lookup(:model=>@sb[:nodeid]), :model=>ui_lookup(:models=>"MiqPolicy")}
        @right_cell_div = "policy_list"
      end
    elsif x_active_tree == :condition_tree
      @conditions = Condition.find_all_by_towhat(@sb[:folder].titleize).sort{|a,b|a.description.downcase<=>b.description.downcase}
      set_search_text
      @conditions = apply_search_filter(@search_text, @conditions) if !@search_text.blank?
      @right_cell_text = "All #{ui_lookup(:model=>@sb[:folder])} Conditions"
      @right_cell_text = _("All %{typ} %{model}") % {:typ=>ui_lookup(:model=>@sb[:folder]), :model=>ui_lookup(:models=>"Condition")}
      @right_cell_div = "condition_list"
    elsif x_active_tree == :alert_profile_tree
      @alert_profiles = MiqAlertSet.all(:conditions=>["mode = ?", @sb[:folder]]).sort{|a,b|a.description.downcase<=>b.description.downcase}
      set_search_text
      @alert_profiles = apply_search_filter(@search_text, @alert_profiles) if !@search_text.blank?
      @right_cell_text = "All #{ui_lookup(:model=>@sb[:folder])} Alert Profiles"
      @right_cell_text = _("All %{typ} %{model}") % {:typ=>ui_lookup(:model=>@sb[:folder]), :model=>ui_lookup(:models=>"MiqAlertSet")}
      @right_cell_div = "alert_profile_list"
    end
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    return x_get_child_nodes_dynatree(x_active_tree, id)
  end

  # Build the audit object when a profile is saved
  def build_saved_audit(record, add = false)
    name = record.respond_to?(:name) ? record.name : record.description
    msg = "[#{name}] Record #{add ? "added" : "updated"} ("
    event = "#{record.class.to_s.downcase}_record_#{add ? "add" : "update"}"
    i = 0
    @edit[:new].each_key do |k|
      if @edit[:new][k] != @edit[:current][k]
        msg = msg + ", " if i > 0
        i += 1
        if k == :members
          msg = msg +  k.to_s + ":[" + @edit[:current][k].keys.join(",") + "] to [" + @edit[:new][k].keys.join(",") + "]"
        else
          msg = msg +  k.to_s + ":[" + @edit[:current][k].to_s + "] to [" + @edit[:new][k].to_s + "]"
        end
      end
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>record.id, :target_class=>record.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  def export_chooser(dbtype="pp",type="export")
    @sb[:new] = Hash.new
    @sb[:dbtype] = dbtype
    @sb[:hide] = false
    if type == "export"
      @sb[:new][:choices_chosen] = Array.new
      @sb[:new][:choices] = Array.new
      @sb[:new][:chosen] = Array.new
      if dbtype == "pp"
        MiqPolicySet.all.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |ps|
          @sb[:new][:choices].push([ps.description, ps.id])
        end
      elsif dbtype == "p"
        MiqPolicy.all.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |p|
          @sb[:new][:choices].push([p.description, p.id])
        end
      elsif dbtype == "al"
        MiqAlert.all.sort{|a,b| a.description.downcase <=> b.description.downcase}.each do |a|
          @sb[:new][:choices].push([a.description, a.id])
        end
      end
    else
      @sb[:import_file] = ""
    end
  end

  def validate_snmp_options(options)
    if options[:host].nil? || options[:host] == ""
      add_flash(_("%s is required") % "Host", :error)
    end
    trap_text = options[:snmp_version] == "v1" || options[:snmp_version].nil? ? "Trap Number" : "Trap Object ID"
    if options[:trap_id].nil? || options[:trap_id] == ""
      add_flash(_("%s is required") % "#{trap_text}", :error)
    end
    options[:variables].each_with_index do |var,i|
      if var[:oid].blank? || var[:value].blank? || var[:var_type] == "<None>"
        if !var[:oid].blank? && var[:var_type] != "<None>" && var[:var_type] != "Null" && var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Value", :field=>var[:oid]}, :error)
        elsif var[:oid].blank? && var[:var_type] != "<None>" && var[:var_type] != "Null" && !var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Object ID", :field=>var[:value]}, :error)
        elsif !var[:oid].blank? && var[:var_type] == "<None>" && var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Type", :field=>var[:oid]}, :error)
          add_flash(_("%{val} missing for %{field}") % {:val=>"Value", :field=>var[:oid]}, :error)
        elsif var[:oid].blank? && var[:var_type] == "Null" && var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Object ID", :field=>var[:var_type]}, :error)
        elsif var[:oid].blank? && var[:var_type] != "<None>" && var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Object ID and Values", :field=>var[:var_type]}, :error)
        elsif var[:oid].blank? && var[:var_type] != "Null" && var[:var_type] != "<None>" && var[:value].blank?
          add_flash(_("%{val} missing for %{field}") % {:val=>"Object ID", :field=>var[:var_type]}, :error)
        end
      end
    end
  end

  def build_snmp_options(subkey, process_variables)
    refresh = false
    @edit[:new][subkey][:host] = params[:host] if params[:host]         # Actions support a single host in this key
    @edit[:new][subkey][:host][0] = params[:host_1] if params[:host_1]  # Alerts support an array of hosts
    @edit[:new][subkey][:host][1] = params[:host_2] if params[:host_2]
    @edit[:new][subkey][:host][2] = params[:host_3] if params[:host_3]
    @edit[:new][subkey][:snmp_version] = params[:snmp_version] if params[:snmp_version]
    @edit[:new][subkey][:trap_id]      = params[:trap_id] if params[:trap_id]
    refresh = true if params[:snmp_version]
    if process_variables
      params.each do |var, val|
        vars = var.split("__")
        if (vars[0] == "oid" || vars[0] == "var_type" || vars[0] == "value")
          10.times do |i|
            f = ("oid__" + (i+1).to_s)
            t = ("var_type__" + (i+1).to_s)
            v = ("value__" + (i+1).to_s)
            @edit[:new][subkey][:variables][i][:oid] = params[f] if params[f.to_s]
            @edit[:new][subkey][:variables][i][:var_type] = params[t] if params[t.to_s]
            if params[t.to_s] == "<None>" || params[t.to_s] == "Null"
              @edit[:new][subkey][:variables][i][:value] = ""
            end
            if params[t.to_s] == "<None>"
              @edit[:new][subkey][:variables][i][:oid] = ""
            end
            refresh = true if params[t.to_s]
            @edit[:new][subkey][:variables][i][:value] = params[v] if params[v.to_s]
          end
        end
      end
    end
    refresh
  end

  def build_expression(parent, model)
    @edit[:new][:expression] = parent.expression.is_a?(MiqExpression) ? parent.expression.exp : nil
    # Populate exp editor fields for the expression column
    @edit[:expression] ||= Hash.new                                     # Create hash for this expression, if needed
    @edit[:expression][:expression] = Array.new                         # Store exps in an array
    @edit[:expression][:exp_idx] = 0                                    # Start at first exp
    if @edit[:new][:expression].blank?
      @edit[:expression][:expression] = {"???"=>"???"}                  # Set as new exp element
      @edit[:new][:expression] = copy_hash(@edit[:expression][:expression])   # Copy to new exp
    else
      @edit[:expression][:expression] = copy_hash(@edit[:new][:expression])
    end
    @edit[:expression_table] = @edit[:expression][:expression] == {"???"=>"???"} ? nil : exp_build_table(@edit[:expression][:expression])

    @expkey = :expression                                               # Set expression key to expression
    exp_array(:init, @edit[:expression][:expression])                   # Initialize the exp array
    @edit[:expression][:exp_table] = exp_build_table(@edit[:expression][:expression])
    @edit[:expression][:exp_model] = model                              # Set model for the exp editor
  end

  def get_session_data
    @title          = "Policies"
    if request.parameters["action"] == "wait_for_task"  # Don't change layout when wait_for_task came in for RSOP
      @layout = session[:layout]
    else
      @layout = params[:action] && params[:action].starts_with?("rsop") ? "miq_policy_rsop" : "miq_policy"
    end
    @lastaction     = session[:miq_policy_lastaction]
    @display        = session[:miq_policy_display]
    @current_page   = session[:miq_policy_current_page]
    alert_build_pulldowns
    @server_options = session[:server_options] if session[:server_options]
  end

  def set_session_data
    session[:layout]                  = @layout
    session[:miq_policy_lastaction]   = @lastaction
    session[:miq_policy_current_page] = @current_page
    session[:miq_policy_display]      = @display unless @display.nil?
    session[:server_options]          = @server_options
  end

end
