module MiqPolicyController::AlertProfiles
  extend ActiveSupport::Concern

  def alert_profile_edit
    case params[:button]
    when "cancel"
      @edit = nil
      @alert_profile = session[:edit][:alert_profile_id] ? MiqAlertSet.find_by_id(session[:edit][:alert_profile_id]) : MiqAlertSet.new

      if @alert_profile && @alert_profile.id.blank?
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model => "MiqAlertSet"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "MiqAlertSet"), :name => @alert_profile.description})
      end
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      alert_profile_build_edit_screen
      @sb[:action] = "alert_profile_edit"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("ap")
      return
    end

    # Load @edit/vars for other buttons
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("alert_profile_edit__#{id}", "replace_cell__explorer")
    @alert_profile = @edit[:alert_profile_id] ? MiqAlertSet.find_by_id(@edit[:alert_profile_id]) : MiqAlertSet.new

    case params[:button]
    when "save", "add"
      assert_privileges("alert_profile_#{@alert_profile.id ? "edit" : "new"}")
      add_flash(_("%{model} must contain at least one %{field}") % {:model => ui_lookup(:model => "MiqAlertSet"), :field => ui_lookup(:model => "MiqAlert")}, :error) if @edit[:new][:alerts].length == 0 # At least one member is required
      alert_profile = @alert_profile.id.blank? ? MiqAlertSet.new : MiqAlertSet.find(@alert_profile.id)  # Get new or existing record
      alert_profile.description = @edit[:new][:description]
      alert_profile.notes = @edit[:new][:notes]
      alert_profile.mode = @edit[:new][:mode]
      if alert_profile.valid? && !@flash_array && alert_profile.save
        alerts = alert_profile.members                        # Get the sets members
        current = alerts.collect(&:id)                        # Build an array of the current alert ids
        mems = @edit[:new][:alerts].invert                    # Get the ids from the member list box
        begin
          alerts.each { |a| alert_profile.remove_member(MiqAlert.find(a)) unless mems.include?(a.id) }  # Remove any alerts no longer in the members list box
          mems.each_key { |m| alert_profile.add_member(MiqAlert.find(m)) unless current.include?(m) }   # Add any alerts not in the set
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") % "Alert Profile #{params[:button]}" << bang.message, :error)
        end
        AuditEvent.success(build_saved_audit(alert_profile, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") :
                                                _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "MiqAlertSet"), :name => @edit[:new][:description]})
        alert_profile_get_info(MiqAlertSet.find(alert_profile.id))
        @edit = nil
        self.x_node = @new_alert_profile_node = "xx-#{alert_profile.mode}_ap-#{to_cid(alert_profile.id)}"
        get_node_info(@new_alert_profile_node)
        replace_right_cell("ap", [:alert_profile])
      else
        alert_profile.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("ap")
      end
    when "move_right", "move_left", "move_allleft"
      handle_selection_buttons(:alerts)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("ap")
    end
  end

  def alert_profile_assign
    assert_privileges("alert_profile_assign")
    @assign = @sb[:assign]
    @alert_profile = @assign[:alert_profile] if @assign
    case params[:button]
    when "cancel"
      @assign = nil
      add_flash(_("%s cancelled by user") % "Edit #{ui_lookup(:model => "MiqAlertSet")} assignments")
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    when "save"
      if @assign[:new][:assign_to].to_s.ends_with?("-tags") && !@assign[:new][:cat]
        add_flash(_("%s must be selected") % "A Tag Category", :error)
      elsif @assign[:new][:assign_to] &&
            (@assign[:new][:assign_to] != "enterprise" && @assign[:new][:objects].length == 0)
        add_flash(_("At least one Selection must be checked"), :error)
      end
      unless flash_errors?
        alert_profile_assign_save
        add_flash(_("Alert Profile \"%s\" assignments succesfully saved") % @alert_profile.description)
        get_node_info(x_node)
        @assign = nil
      end
      replace_right_cell("ap")
    when "reset", nil # Reset or first time in
      alert_profile_build_assign_screen
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("ap")
    end
  end

  def alert_profile_delete
    alert_profiles = []
    # showing 1 alert set, delete it
    if params[:id].nil? || MiqAlertSet.find_by_id(params[:id]).nil?
      add_flash(_("%s no longer exists") % ui_lookup(:model => "MiqAlertSet"),
                :error)
    else
      alert_profiles.push(params[:id])
    end
    process_alert_profiles(alert_profiles, "destroy") unless alert_profiles.empty?
    add_flash(_("The selected %s was deleted") % ui_lookup(:models => "MiqAlertSet")) if @flash_array.nil?
    nodes = x_node.split("_")
    nodes.pop
    self.x_node = nodes.join("_")
    get_node_info(x_node)
    replace_right_cell("xx", [:alert_profile])
  end

  def alert_profile_field_changed
    return unless load_edit("alert_profile_edit__#{params[:id]}", "replace_cell__explorer")
    @alert_profile = @edit[:alert_profile_id] ? MiqAlertSet.find_by_id(@edit[:alert_profile_id]) : MiqAlertSet.new

    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:notes] = params[:notes].blank? ? nil : params[:notes] if params[:notes]

    send_button_changes
  end

  def alert_profile_assign_changed
    @assign = @sb[:assign]
    @alert_profile = @assign[:alert_profile]

    if params.key?(:chosen_assign_to)
      @assign[:new][:assign_to] = params[:chosen_assign_to].blank? ? nil : params[:chosen_assign_to]
      @assign[:new][:cat] = nil                                 # Clear chosen tag category
    end
    @assign[:new][:cat] = params[:chosen_cat].blank? ? nil : params[:chosen_cat].to_i if params.key?(:chosen_cat)
    if params.key?(:chosen_assign_to) || params.key?(:chosen_cat)
      @assign[:new][:objects] = []                       # Clear selected objects
      @objects = alert_profile_get_assign_to_objects   # Get the assigned objects
      @assign[:obj_tree] = alert_profile_build_obj_tree         # Build the selection tree
    end
    if params.key?(:id)
      if params[:check] == "1"
        @assign[:new][:objects].push(params[:id].split("_").last.to_i)
        @assign[:new][:objects].sort!
      else
        @assign[:new][:objects].delete(params[:id].split("_").last.to_i)
      end
    end

    send_button_changes
  end

  private

  def process_alert_profiles(alert_profiles, task)
    process_elements(alert_profiles, MiqAlertSet, task)
  end

  # Gather up the object ids based on the assignment selections
  def alert_profile_get_assign_to_objects
    objs = []
    unless @assign[:new][:assign_to] == "enterprise"          # No further selection needed for enterprise
      if @assign[:new][:assign_to]                            # Assign to selected
        if @assign[:new][:assign_to].ends_with?("-tags")
          if @assign[:new][:cat]                              # Tag category selected
            objs = Classification.find(@assign[:new][:cat]).entries
          end
        else                                                  # Model selected
          objs = @assign[:new][:assign_to].camelize.constantize.all
        end
      end
    end
    objs
  end

  # Build the assign objects selection tree
  def alert_profile_build_obj_tree
    tree = nil
    unless @objects.empty?               # Build object tree
      if @assign[:new][:assign_to] == "ems_folder"
        tree = build_belongsto_tree(@assign[:new][:objects].collect { |f| "EmsFolder_#{f}" }, true, false)
      elsif @assign[:new][:assign_to] == "resource_pool"
        tree = build_belongsto_tree(@assign[:new][:objects].collect { |f| "ResourcePool_#{f}" }, false, false, true)
      else
        root_node = TreeNodeBuilder.generic_tree_node(
          "OBJROOT",
          @assign[:new][:assign_to].ends_with?("-tags") ? "Tags" : ui_lookup(:tables => @assign[:new][:assign_to]),
          "folder_open.png",
          "",
          :style_class  => "cfme-no-cursor-node",
          :expand       => true,
          :hideCheckbox => true
        )
        root_node[:children] = []
        @objects.sort_by { |o| (o[:name] || o[:description]).downcase }.each do |o|
          if @assign[:new][:assign_to].ends_with?("-tags")
            icon = "tag.png"
          else
            if @assign[:new][:assign_to] == "ext_management_system"
              icon = "vendor-#{o.image_name}.png"
            elsif @assign[:new][:assign_to] == "resource_pool"
              icon = o.vapp ? "vapp.png" : "resource_pool.png"
            else
              icon = "#{@assign[:new][:assign_to]}.png"
            end
          end
          node = TreeNodeBuilder.generic_tree_node(
            o.id,
            o[:name] || o[:description],
            icon,
            "",
            :select => @assign[:new][:objects].include?(o.id) # Check if tag is assigned
          )
          root_node[:children].push(node)
        end
        tree = root_node.to_json
      end
    end
    tree
  end

  def alert_profile_build_edit_screen
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}

    @alert_profile = params[:id] ? MiqAlertSet.find(params[:id]) : MiqAlertSet.new  # Get existing or new record
    @edit[:key] = "alert_profile_edit__#{@alert_profile.id || "new"}"
    @edit[:rec_id] = @alert_profile.id || nil

    @edit[:alert_profile_id] = @alert_profile.id
    @edit[:new][:description] = @alert_profile.description
    @edit[:new][:notes] = @alert_profile.notes
    @edit[:new][:mode] = @alert_profile.mode || @sb[:folder]  # Use existing model or model from selected folder

    @edit[:new][:alerts] = {}
    alerts = @alert_profile.members # Get the set's members
    alerts.each { |a| @edit[:new][:alerts][a.description] = a.id } # Build a hash for the members list box

    @edit[:choices] = {}
    MiqAlert.all(:conditions => ["db = ?", @edit[:new][:mode]]).each do |a|
      @edit[:choices][a.description] = a.id           # Build a hash for the alerts to choose from
    end

    @edit[:new][:alerts].each_key do |key|
      @edit[:choices].delete(key)                     # Remove any alerts that are in the members list box
    end

    @edit[:current] = copy_hash(@edit[:new])

    @embedded = true
    @in_a_form = true
    @edit[:current][:add] = true unless @edit[:alert_profile_id] # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def alert_profile_build_assign_screen
    @assign = {}
    @assign[:new] = {}
    @assign[:current] = {}
    @sb[:action] = "alert_profile_assign"
    @assign[:rec_id] = params[:id]

    @alert_profile = MiqAlertSet.find(params[:id])            # Get existing record
    @assign[:alert_profile] = @alert_profile

    @assign[:cats] = {}
    Classification.categories.collect do |c|
      c if !c.read_only? && c.show && c.entries.size > 0
    end.compact.each { |c| @assign[:cats][c.id] = c.description }

    @assign[:new][:assign_to] = nil
    @assign[:new][:cat] = nil
    @assign[:new][:objects] = []
    aa = @alert_profile.get_assigned_tos
    if !aa[:objects].empty?                                   # Objects are assigned
      if aa[:objects].first.kind_of?(MiqEnterprise)           # Assigned to Enterprise object
        @assign[:new][:assign_to] = "enterprise"
      else                                                    # Assigned to CIs
        @assign[:new][:assign_to] = aa[:objects].first.class.base_class.to_s.underscore
        @assign[:new][:objects] = aa[:objects].collect(&:id).sort!
      end
    elsif !aa[:tags].empty?                                   # Tags are assigned
      @assign[:new][:assign_to] = aa[:tags].first.last + "-tags"
      @assign[:new][:cat] = aa[:tags].first.first.parent_id
      @assign[:new][:objects] = aa[:tags].collect { |o| o.first.id }
    end
    @objects = alert_profile_get_assign_to_objects   # Get the assigned objects
    @assign[:obj_tree] = alert_profile_build_obj_tree         # Build the selection tree

    @assign[:current] = copy_hash(@assign[:new])

    @embedded = true
    @in_a_form = true
    session[:changed] = (@assign[:new] != @assign[:current])
  end

  # Save alert profile assignments
  def alert_profile_assign_save
    @alert_profile.remove_all_assigned_tos                # Remove existing assignments
    if @assign[:new][:assign_to]                          # If an assignment is selected
      if @assign[:new][:assign_to] == "enterprise"        # Assign to enterprise
        @alert_profile.assign_to_objects(MiqEnterprise.first)
      elsif @assign[:new][:assign_to].ends_with?("-tags") # Assign to selected tags
        @alert_profile.assign_to_tags(@assign[:new][:objects], @assign[:new][:assign_to].split("-").first)
      elsif @assign[:new][:assign_to]                     # Assign to selected objects
        @alert_profile.assign_to_objects(@assign[:new][:objects], @assign[:new][:assign_to])
      end
    end
  end

  def alert_profile_get_all_folders
    @ap_folders = MiqAlert.base_tables.sort_by { |db| ui_lookup(:model => db) }.collect do |db|
      [ui_lookup(:model => db), db]
    end
    #   @folders = ["Compliance", "Control"]
    @right_cell_text = _("All %s") % ui_lookup(:models => "MiqAlertSet")
    @right_cell_div = "alert_profile_folders"
  end

  def alert_profile_get_all
    @alert_profiles = MiqAlertSet.all.sort_by { |as| as.description.downcase }
    set_search_text
    @alert_profiles = apply_search_filter(@search_text, @alert_profiles) unless @search_text.blank?
    @right_cell_text = _("All %s") % ui_lookup(:models => "MiqAlertSet")
    @right_cell_div = "alert_profile_list"
  end

  # Get information for an alert profile
  def alert_profile_get_info(alert_profile)
    @record = @alert_profile = alert_profile
    aa = @alert_profile.get_assigned_tos
    @alert_profile_tag = Classification.find(aa[:tags].first.first.parent_id) unless aa[:tags].empty?
    @alert_profile_alerts = @alert_profile.miq_alerts.sort_by { |a| a.description.downcase }
    @right_cell_text = _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "MiqAlertSet"), :name => alert_profile.description}
    @right_cell_div = "alert_profile_details"
  end
end
