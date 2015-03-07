module MiqPolicyController::PolicyProfiles
  extend ActiveSupport::Concern

  def profile_edit
    case params[:button]
    when "cancel"
      @edit = nil
      @profile = MiqPolicySet.find_by_id(session[:edit][:profile_id]) if session[:edit] && session[:edit][:profile_id]
      if !@profile || (@profile && @profile.id.blank?)
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"MiqPolicySet"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"MiqPolicySet"), :name=>@profile.description})
      end
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      profile_build_edit_screen
      @sb[:action] = "profile_edit"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("pp")
      return
    end

    # Load @edit/vars for other buttons
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("profile_edit__#{id}","replace_cell__explorer")
    @profile = @edit[:profile_id] ? MiqPolicySet.find_by_id(@edit[:profile_id]) : MiqPolicySet.new

    case params[:button]
    when "save", "add"
      assert_privileges("profile_#{@profile.id ? "edit" : "new"}")
      add_flash(_("%{model} must contain at least one %{field}") % {:model=>ui_lookup(:model=>"MiqPolicySet"), :field=>ui_lookup(:model=>"MiqPolicy")}, :error) if @edit[:new][:policies].length == 0 # At least one member is required
      profile = @profile.id.blank? ? MiqPolicySet.new : MiqPolicySet.find(@profile.id)  # Get new or existing record
      profile.description = @edit[:new][:description]
      profile.notes = @edit[:new][:notes]
      if profile.valid? && !@flash_array && profile.save
        policies = profile.members                            # Get the sets members
        current = Array.new
        policies.each {|p| current.push(p.id)}                # Build an array of the current policy ids
        mems = @edit[:new][:policies].invert                  # Get the ids from the member list box
        begin
          policies.each {|c| profile.remove_member(MiqPolicy.find(c)) if !mems.include?(c.id) } # Remove any policies no longer in the members list box
          mems.each_key {|m| profile.add_member(MiqPolicy.find(m)) if !current.include?(m) }    # Add any policies not in the set
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") % "Policy Profile #{params[:button]}" << bang.message, :error)
        end
        AuditEvent.success(build_saved_audit(profile, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") :
                                                _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "MiqPolicySet"), :name => @edit[:new][:description]})
        profile_get_info(MiqPolicySet.find(profile.id))
        @edit = nil
        @nodetype = "pp"
        @new_profile_node = "pp-#{to_cid(profile.id)}"
        replace_right_cell("pp", [:policy_profile])
      else
        profile.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("pp")
      end
    when "move_right", "move_left", "move_allleft"
      handle_selection_buttons(:policies)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("pp")
    end
  end

  def profile_delete
    assert_privileges("profile_delete")
    profiles = Array.new
    # showing 1 policy set, delete it
    if params[:id] == nil || MiqPolicySet.find_by_id(params[:id]).nil?
      add_flash(_("%s no longer exists") % ui_lookup(:model=>"MiqPolicySet"),
                  :error)
    else
      profiles.push(params[:id])
    end
    process_profiles(profiles, "destroy") unless profiles.empty?
    add_flash(_("The selected %s was deleted") % ui_lookup(:models=>"MiqPolicySet")) if @flash_array == nil
    self.x_node = @new_profile_node = 'root'
    get_node_info('root')
    replace_right_cell('root', [:policy_profile])
  end

  def profile_field_changed
    return unless load_edit("profile_edit__#{params[:id]}","replace_cell__explorer")
    @profile = @edit[:profile_id] ? MiqPolicySet.find_by_id(@edit[:profile_id]) : MiqPolicySet.new

    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:notes] = params[:notes].blank? ? nil : params[:notes] if params[:notes]

    send_button_changes
  end

  private

  def process_profiles(profiles, task)
    process_elements(profiles, MiqPolicySet, task)
  end

  def profile_build_edit_screen
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @profile = params[:id] ? MiqPolicySet.find(params[:id]) : MiqPolicySet.new            # Get existing or new record
    @edit[:key] = "profile_edit__#{@profile.id || "new"}"
    @edit[:rec_id] = @profile.id || nil

    @edit[:profile_id] = @profile.id
    @edit[:new][:description] = @profile.description
    @edit[:new][:notes] = @profile.notes

    @edit[:new][:policies] = Hash.new
    policies = @profile.members     # Get the member sets
    policies.each{|p| @edit[:new][:policies][ui_lookup(:model=>p.towhat) + " #{p.mode.capitalize}: " + p.description] = p.id} # Build a hash for the members list box

    @edit[:choices] = Hash.new
    MiqPolicy.all.each do |p|
      @edit[:choices][ui_lookup(:model=>p.towhat) + " #{p.mode.capitalize}: " + p.description] = p.id         # Build a hash for the policies to choose from
    end

    @edit[:new][:policies].each_key do |key|
      @edit[:choices].delete(key)                     # Remove any policies that are in the members list box
    end

    @edit[:current] = copy_hash(@edit[:new])

    @embedded = true
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:profile_id].blank?                             # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def profile_get_all
    @profiles = MiqPolicySet.all.sort_by { |ps| ps.description.downcase }
    set_search_text
    @profiles = apply_search_filter(@search_text, @profiles) if !@search_text.blank?
    @right_cell_text = _("All %s") % ui_lookup(:models=>"MiqPolicySet")
    @right_cell_div = "profile_list"
  end

  # Get information for a profile
  def profile_get_info(profile)
    @record = @profile = profile
    @profile_policies = @profile.miq_policies.sort_by { |p| [p.towhat, p.mode, p.description.downcase] }
    @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqPolicySet"), :name=>@profile.description}
    @right_cell_div = "profile_details"
  end

  def profile_build_tree(type=:policy_profile, name=:policy_profile_tree)
    x_tree_init(name, type, 'MiqPolicySet', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root = tree_nodes.first
    root[:title] = "All Policy Profiles"
    root[:tooltip] = "All Policy Profiles"
    root[:icon] = "folder.png"

    @temp[name] = tree_nodes.to_json  # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)    # Set active node to root if not set
  end

  def profile_get_all
    @profiles = MiqPolicySet.all.sort_by { |ps| ps.description.downcase }
    set_search_text
    @profiles = apply_search_filter(@search_text, @profiles) if !@search_text.blank?
    @right_cell_text = _("All %s") % ui_lookup(:models=>"MiqPolicySet")
    @right_cell_div = "profile_list"
  end

end
