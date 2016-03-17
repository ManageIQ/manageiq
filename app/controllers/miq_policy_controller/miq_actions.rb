module MiqPolicyController::MiqActions
  extend ActiveSupport::Concern

  def action_edit
    assert_privileges(params[:pressed]) if params[:pressed]
    case params[:button]
    when "cancel"
      @edit = nil
      @action = MiqAction.find_by_id(session[:edit][:action_id]) if session[:edit] && session[:edit][:action_id]
      if @action && @action.id
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "MiqAction"), :name => @action.description})
      else
        add_flash(_("Add of new %{models} was cancelled by the user") % {:models => ui_lookup(:model => "MiqAction")})
      end
      @sb[:action] = nil
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      action_build_edit_screen
      @sb[:action] = "action_edit"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("a")
      return
    end

    # Load @edit/vars for other buttons
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("action_edit__#{id}", "replace_cell__explorer")
    @action = @edit[:action_id] ? MiqAction.find_by_id(@edit[:action_id]) : MiqAction.new
    case params[:button]
    when "save", "add"
      action = @action.id.blank? ? MiqAction.new : MiqAction.find(@action.id) # Get new or existing record

      # set email "from" to default value if it's not present
      if @edit[:new][:action_type] == "email" && @edit[:new][:options][:from].nil?
        @edit[:new][:options][:from] = "cfadmin@cfserver.com"
      end

      action_set_record_vars(action)
      if action_valid_record?(action) && !@flash_array && action.save
        AuditEvent.success(build_saved_audit(action, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") :
                                                _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "MiqAction"), :name => @edit[:new][:description]})
        action_get_info(MiqAction.find(action.id))
        @edit = nil
        @nodetype = "a"
        @new_action_node = "a-#{to_cid(action.id)}"
        replace_right_cell("a", params[:button] == "save" ? [:policy_profile, :policy, :action] : [:action])
        @sb[:action] = nil
      else
        action.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|                    # Use RJS to update the display
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "move_right", "move_left", "move_allleft"
      action_handle_selection_buttons(:alerts)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("a")
    end
  end

  def action_delete
    assert_privileges("action_delete")
    actions = []
    # showing 1 action, delete it
    if params[:id].nil? || MiqAction.find_by_id(params[:id]).nil?
      add_flash(_("%{models} no longer exists") % {:models => ui_lookup(:model => "MiqAction")},
                :error)
    else
      actions.push(params[:id])
    end
    process_actions(actions, "destroy") unless actions.empty?
    add_flash(_("The selected %{models} was deleted") %
      {:models => ui_lookup(:models => "MiqAction")}) if @flash_array.nil?
    @new_action_node = self.x_node = "root"
    get_node_info(x_node)
    replace_right_cell("root", [:action])
  end

  def action_field_changed
    return unless load_edit("action_edit__#{params[:id]}", "replace_cell__explorer")
    @action = @edit[:action_id] ? MiqAction.find_by_id(@edit[:action_id]) : MiqAction.new

    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:options][:from] = params[:from].blank? ? nil : params[:from] if params[:from]
    @edit[:new][:options][:to] = params[:to].blank? ? nil : params[:to] if params[:to]
    @edit[:new][:options][:name] = params[:snapshot_name].blank? ? nil : params[:snapshot_name] if params[:snapshot_name]
    @edit[:new][:options][:age] = params[:snapshot_age].to_i if params.key?(:snapshot_age)
    @edit[:new][:options][:parent_type] = params[:parent_type].blank? ? nil : params[:parent_type] if params[:parent_type]
    if params[:cpu_value]
      @edit[:new][:options][:value] = params[:cpu_value]
    elsif params[:memory_value]
      @edit[:new][:options][:value] = params[:memory_value]
    end
    @edit[:new][:options][:attribute] = params[:attribute] if params[:attribute]
    @edit[:new][:options][:value] = params[:value] if params[:value]
    @edit[:new][:options][:ae_message] = params[:object_message] if params.key?(:object_message)
    @edit[:new][:options][:ae_request]  = params[:object_request] if params[:object_request]
    params.each do |var, val|
      vars = var.split("_")
      if (vars[0] == "attribute" || vars[0] == "value") && !val.blank?
        AE_MAX_RESOLUTION_FIELDS.times do |i|
          f = ("attribute_" + (i + 1).to_s)
          v = ("value_" + (i + 1).to_s)
          @edit[:new][:attrs][i][0] = params[f] if params[f.to_sym]
          @edit[:new][:attrs][i][1] = params[v] if params[v.to_sym]
        end
      elsif vars[0] == "cat"  # Handle category check boxes
        @edit[:new][:options][:cats] ||= []
        if val == "1"
          @edit[:new][:options][:cats].push(vars[1..-1].join("_"))  # Add the category
        else
          @edit[:new][:options][:cats].delete(vars[1..-1].join("_"))  # Remove the category
          @edit[:new][:options][:cats] = nil if @edit[:new][:options][:cats].blank?
        end
      end
    end
    @snmp_trap_refresh = build_snmp_options(:options, @edit[:new][:action_type] == "snmp_trap")
    @edit[:new][:options][:scan_item_set_name] = params[:analysis_profile] if params[:analysis_profile]

    if params[:miq_action_type] && params[:miq_action_type] != @edit[:new][:action_type]  # action type was changed
      @edit[:new][:action_type] = params[:miq_action_type]
      @edit[:new][:options] = {}  # Clear out the options
      action_build_alert_choices if params[:miq_action_type] == "evaluate_alerts"         # Build alert choices hash
      action_build_snmp_variables if params[:miq_action_type] == "snmp_trap"            # Build snmp_trap variables hash
      if params[:miq_action_type] == "tag"
        get_tags_tree
      end
      @action_type_changed = true
    end

    send_button_changes
  end

  def action_tag_pressed
    @edit = session[:edit]
    @action = @edit[:action_id] ? MiqAction.find_by_id(@edit[:action_id]) : MiqAction.new
    tag_name = params[:id].split('__')[1]
    @tag_selected = Classification.tag2human(tag_name)
    @edit[:new][:options][:tags] = {} unless tag_name.nil?
    @edit[:new][:options][:tags] = [tag_name] unless tag_name.nil?

    send_button_changes
  end

  def action_get_all
    peca_get_all('action', -> { get_view(MiqAction) })
  end

  private

  def process_actions(actions, task)
    process_elements(actions, MiqAction, task)
  end

  def get_tags_tree
    cats = Classification.categories.select(&:show).sort_by(&:name)
    unless cats.nil?
      action_build_cat_tree(cats)
    end
  end

  def action_build_snmp_variables
    @edit[:new][:options][:snmp_version] = "v1" if @edit[:new][:action_type] == "snmp_trap" && @edit[:new][:options][:snmp_version].blank?
    @edit[:snmp_var_types] = MiqSnmp.available_types
    @edit[:new][:options][:variables] ||= []
    10.times do |i|
      @edit[:new][:options][:variables][i] ||= {}
      @edit[:new][:options][:variables][i][:oid] ||= ""
      @edit[:new][:options][:variables][i][:var_type] ||= "<None>"
      @edit[:new][:options][:variables][i][:value] ||= ""
    end
  end

  # Handle the middle buttons on the Action add/edit Alerts form
  # pass in member list symbols (i.e. :policies)
  def action_handle_selection_buttons(members,
                                      members_chosen = :members_chosen,
                                      choices = :choices,
                                      choices_chosen = :choices_chosen)
    if params[:button].ends_with?("_left")
      if params[members_chosen].nil?
        add_flash(_("No %{members} were selected to move left") %
          {:members => members.to_s.split("_").first.titleize}, :error)
      else
        mems = @edit[:new][members].invert
        params[members_chosen].each do |mc|
          @edit[choices][mems[mc]] = mc
          @edit[:new][members].delete(mems[mc])
        end
      end
    elsif params[:button].ends_with?("_right")
      if params[choices_chosen].nil?
        add_flash(_("No %{members} were selected to move right") %
          {:members => members.to_s.split("_").first.titleize}, :error)
      else
        mems = @edit[choices].invert
        params[choices_chosen].each do |mc|
          @edit[:new][members][mems[mc]] = mc
          @edit[choices].delete(mems[mc])
        end
      end
    elsif params[:button].ends_with?("_allleft")
      if @edit[:new][members].length == 0
        add_flash(_("No %{members} were selected to move left") %
          {:members => members.to_s.split("_").first.titleize}, :error)
      else
        @edit[:new][members].each do |key, value|
          @edit[choices][key] = value
        end
        @edit[:new][members].clear
      end
    end
  end

  def action_build_edit_screen
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}

    @action = params[:id] ? MiqAction.find(params[:id]) : MiqAction.new           # Get existing or new record
    @edit[:key] = "action_edit__#{@action.id || "new"}"
    @edit[:rec_id] = @action.id || nil

    @edit[:action_id] = @action.id
    @edit[:new][:description] = @action.description
    @edit[:new][:action_type] = @action.action_type.blank? ? "" : @action.action_type
    if @action.options
      @edit[:new][:options] = copy_hash(@action.options)
    else
      @edit[:new][:options] = {}
    end

    @edit[:new][:object_message] = @edit[:new][:options][:ae_message] unless @edit[:new][:options][:ae_message].nil?
    @edit[:new][:object_request] = @edit[:new][:options][:ae_request] unless @edit[:new][:options][:ae_request].nil?
    @edit[:new][:attrs] ||= []
    AE_MAX_RESOLUTION_FIELDS.times { @edit[:new][:attrs].push([]) }
    unless @edit[:new][:options][:ae_hash].nil?
      @edit[:new][:options][:ae_hash].each_with_index do |kv, i|
        @edit[:new][:attrs][i][0] = kv[0]
        @edit[:new][:attrs][i][1] = kv[1]
      end
    end

    unless @edit[:new][:options][:tags].nil?
      cats =  Classification.categories.select(&:show).sort_by(&:name)
      cats.each do |c|
        c.entries.each do |e|
          if e.tag.name == @edit[:new][:options][:tags][0]
            @tag_selected = c.description + ": " + e.description
          end
        end
      end
    end

    @edit[:new][:scan_profiles] = ScanItemSet.order(:name).pluck(:name)

    action_build_alert_choices
    unless @edit[:new][:options][:alert_guids].nil?
      @edit[:new][:options][:alert_guids].each do |ag|      # Add alerts to the alert_members hash
        alert = MiqAlert.find_by_guid(ag)
        @edit[:new][:alerts][alert.description] = ag unless alert.nil?
      end
      @edit[:new][:alerts].each do |am|
        @edit[:choices].delete(am.first)              # Remove any choices already in the list
      end
    end
    action_build_snmp_variables if @action.action_type == "snmp_trap"

    # Build arrays for inherit/remove_tags action types
    @edit[:tag_parent_types] =  [["<Choose>", nil],
                                 [ui_lookup(:table => "ems_cluster"), "ems_cluster"],
                                 ["Host", "host"],
                                 [ui_lookup(:table => "storage"), "storage"],
                                 ["Resource Pool", "parent_resource_pool"]
                                ].sort_by { |x| x.first.downcase }
    @edit[:cats] = MiqAction.inheritable_cats.sort_by { |c| c.description.downcase }.collect { |c| [c.name, c.description] }

    @edit[:current] = copy_hash(@edit[:new])
    get_tags_tree
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:action_id].nil?  # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  # Build the alert choice hash for evaluate_alerts action_type
  def action_build_alert_choices
    @edit[:choices] = {}                          # Build a new choices list for true actions
    MiqAlert.all.each do |a|                     # Build the hash of alert choices
      @edit[:choices][a.description] =  a.guid
    end
    @edit[:new][:alerts] = {}                     # Clear out the alerts hash
  end

  # Build the categories/tags tree node
  def action_build_cat_tree(cats)
    r_node = {}                           # Root node
    r_node = TreeNodeBuilder.generic_tree_node(
      "r_#{current_tenant.name}",
      "#{current_tenant.name} Tags",
      "",
      "#{current_tenant.name} Tags",
      :style_class => "cfme-no-cursor-node",
      :expand      => true
    )
    if cats.length > 0
      r_kids = []
      cats.sort_by { |c| c.description.downcase }.each do |c|
        unless c.read_only
          c_node = {}                       # Build the category nodes
          c_node = TreeNodeBuilder.generic_tree_node(
            "c_#{c.id}",
            c.description,
            "",
            c.description,
            :style_class => "cfme-no-cursor-node"
          )
          if c.entries.length > 0
            c_kids ||= []
            c.entries.sort_by { |t| t.description.downcase }.each do |t|
              t_node = {}                   # Build the tag nodes
              t_node = TreeNodeBuilder.generic_tree_node(
                "t__#{t.tag.name}",
                t.description,
                "blank.gif",
                t.description
              )
              c_kids.push(t_node)
            end
            c_node[:children] = c_kids
          end
          # don't add categories that do not have any entries
          r_kids.push(c_node) unless c_node[:children].nil?
        end
      end
      r_node[:children] = r_kids
    end
    @cat_tree = r_node.to_json
  end

  # Set action record variables to new values
  def action_set_record_vars(action)
    action.description = @edit[:new][:description]
    action.action_type = @edit[:new][:action_type]
    if @edit[:new][:attrs]
      @edit[:new][:attrs].each do |pair|
        @edit[:new][:options][:ae_hash] ||= {}
        @edit[:new][:options][:ae_hash][pair[0]] = pair[1] if !pair[0].blank? && !pair[1].blank?
      end
    end
    @edit[:new][:options].delete("ae_hash".to_sym) if @edit[:new][:options][:ae_hash].empty?
    @edit[:new][:object_message] = @edit[:new][:options][:ae_message] unless @edit[:new][:options][:ae_message].nil?
    @edit[:new][:object_request] = @edit[:new][:options][:ae_request] unless @edit[:new][:options][:ae_request].nil?

    if @edit[:new][:action_type] == "evaluate_alerts"   # Handle evaluate_alerts action type
      @edit[:new][:options][:alert_guids] = []   # Create the array in options
      @edit[:new][:alerts].each_value do |a|            # Go thru the alerts hash
        @edit[:new][:options][:alert_guids].push(a)     # Add all alert guids to the array
      end
    end

    if @edit[:new][:options]
      if @edit[:new][:options][:scan_item_set_name]
        action.options = Hash.new
        action.options[:scan_item_set_name] = @edit[:new][:options][:scan_item_set_name]
      else
        action.options = copy_hash(@edit[:new][:options])
      end
    end
  end

  # Check action record variables
  def action_valid_record?(rec)
    edit = @edit[:new]
    options = edit[:options]
    add_flash(_("Description is required"), :error) if edit[:description].blank?
    add_flash(_("Action Type must be selected"), :error) if edit[:action_type].blank?
    if edit[:action_type] == "assign_scan_profile" && options[:scan_item_set_name].blank?
      add_flash(_("Analysis Profile is required"), :error)
    end
    if edit[:action_type] == "set_custom_attribute" && options[:attribute].blank?
      add_flash(_("Attribute Name is required"), :error)
    end
    edit[:attrs].each do |k, v|
      add_flash(_("Attribute missing for %{field}") % {:field => v}, :error) if k.blank? && !v.blank?
      add_flash(_("Value missing for %{field}") % {:field => k}, :error) if !k.blank? && v.blank?
    end
    if edit[:action_type] == "evaluate_alerts" && edit[:alerts].empty?
      add_flash(_("At least one Alert must be selected"), :error)
    end
    if edit[:action_type] == "inherit_parent_tags" && options[:parent_type].blank?
      add_flash(_("Parent Type must be selected"), :error)
    end
    if ["inherit_parent_tags", "remove_tags"].include?(edit[:action_type]) && options[:cats].blank?
      add_flash(_("At least one Category must be selected"), :error)
    end
    if edit[:action_type] == "delete_snapshots_by_age" && options[:age].blank?
      add_flash(_("Snapshot Age must be selected"), :error)
    end
    if edit[:action_type] == "email"
      add_flash(_("E-mail address 'From' is not valid"), :error) unless edit[:options][:from].to_s.email?
      add_flash(_("E-mail address 'To' is not valid"), :error) unless edit[:options][:to].to_s.email?
    end
    if edit[:action_type] == "snmp_trap"
      validate_snmp_options(options)
      unless @flash_array
        rec[:options][:variables] = options[:variables].reject { |var| var[:oid].blank? }
      end
    end
    if edit[:action_type] == "tag" && options[:tags].blank?
      add_flash(_("At least one Tag must be selected"), :error)
    end
    @flash_array.nil?
  end

  # Get information for an action
  def action_get_info(action)
    @record = @action = action
    @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "MiqAction"), :name => action.description}
    @right_cell_div = "action_details"
    @alert_guids = []
    if action.options && action.options[:alert_guids]
      @alert_guids = MiqAlert.where(:guid => action.options[:alert_guids])
    end

    if x_active_tree == :action_tree
      @action_policies = @action.miq_policies.sort_by { |p| p.description.downcase }
    end

    if %w(inherit_parent_tags remove_tags).include?(@action.action_type)
      @cats = Classification.find_by_names(@action.options[:cats]).pluck(:description).sort_by(&:downcase).join(" | ")
    end
  end
end
