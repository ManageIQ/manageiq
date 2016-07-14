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
      send(@hist[:action])
    else                        # Normal explorer tree/link click
      params[:id] = @hist[:id]
      tree_select
    end
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
    'shelve'           => :s1, 'shelve_offload'            => :s1,

    # group 2
    'clone'        => :s2, 'compare'          => :s2, 'drift'           => :s2,
    'edit'         => :s2, 'evm_relationship' => :s2, 'migrate'         => :s2,
    'ownership'    => :s2, 'policy_sim'       => :s2, 'protect'         => :s2,
    'publish'      => :s2, 'reconfigure'      => :s2, 'miq_request_new' => :s2,
    'retire'       => :s2, 'right_size'       => :s2, 'snapshot_add'    => :s2,
    'tag'          => :s2, 'timeline'         => :s2, 'resize'          => :s2,
    'live_migrate' => :s2, 'attach'           => :s2, 'detach'          => :s2,
    'evacuate'     => :s2, 'service_dialog'   => :s2,

    # specials
    'perf'         => :show,
    'download_pdf' => :show,
    'perf_reload'  => :perf_chart_chooser,
    'perf_refresh' => :perf_refresh_data,
  }.freeze

  def x_button
    model, action = pressed2model_action(params[:pressed])

    allowed_models = %w(common image instance vm miq_template provider storage configscript)
    raise ActionController::RoutingError.new('invalid button action') unless
      allowed_models.include?(model)

    # guard this 'router' by matching against a list of allowed actions
    raise ActionController::RoutingError.new('invalid button action') unless
      X_BUTTON_ALLOWED_ACTIONS.key?(action)

    @explorer = true

    method = "#{model}_#{action}"

    # Process model actions that are currently implemented
    if X_BUTTON_ALLOWED_ACTIONS[action] == :s1
      send(method)
    elsif X_BUTTON_ALLOWED_ACTIONS[action] == :s2
      # don't need to set params[:id] and do find_checked_items for methods
      # like ownership, the code in those methods handle it
      if %w(edit right_size resize attach detach live_migrate evacuate).include?(action)
        @_params[:id] = (params[:id] ? [params[:id]] : find_checked_items)[0]
      end
      if ['protect', 'tag'].include?(action)
        case model
        when 'storage'
          send(method, Storage)
        else
          send(method, VmOrTemplate)
        end
      else
        send(method)
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

    if @refresh_partial == "layouts/flash_msg"
      javascript_flash
    elsif @refresh_partial
      # no need to render anything when download_pdf button is pressed on summary screen
      replace_right_cell unless action == 'download_pdf'
    else
      add_flash(_("Button not yet implemented %{model}:%{action}") %
        {:model => model, :action => action}, :error) unless @flash_array
      javascript_flash
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
      return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
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
    @right_cell_text = _("Editing %{model} Tags for \"%{name}\"") % {:name  => ui_lookup(:models => @tagging),
                                                                     :model => current_tenant.name}
    replace_right_cell(@sb[:action])
  end

  # Set form vars for tag editor
  def x_tags_set_form_vars
    @edit = {}
    @edit[:new] = {}
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
    return unless load_edit("#{session[:tag_db]}_edit_tags__#{id}", "replace_cell__explorer")
    add_flash(_("Tag Edit was cancelled by the user"))
    get_node_info(x_node)
    @edit = nil # clean out the saved info
    replace_right_cell
  end

  def x_edit_tags_save
    tagging_edit_tags_save_and_replace_right_cell
  end

  def x_build_node_id(object, options = {})
    TreeNodeBuilder.build_id(object, nil, options)
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    TreeBuilder.tree_add_child_nodes(@sb,
                                     x_tree[:klass_name],
                                     id)
  end

  def rbac_filtered_objects(objects, options = {})
    Rbac.filtered(objects, options)
  end

  # FIXME: move partly to Tree once Trees are made from TreeBuilder
  def valid_active_node(treenodeid)
    modelname, rec_id, nodetype = TreeBuilder.extract_node_model_and_id(treenodeid)
    return treenodeid if ["root", ""].include?(nodetype) # incase node is root or doesn't have a prefix
    raise _("No Class found for explorer tree node id '%{number}'") % {:number => treenodeid} if modelname.nil?
    kls = modelname.constantize
    return treenodeid if kls == Hash

    unless kls.where(:id => from_cid(rec_id)).exists?
      @replace_trees = [@sb[:active_accord]] # refresh trees
      self.x_node = "root"
      add_flash(_("Last selected %{record_name} no longer exists") %
        {:record_name => ui_lookup(:model => kls.to_s)}, :error)
    end
    x_node
  end
end
