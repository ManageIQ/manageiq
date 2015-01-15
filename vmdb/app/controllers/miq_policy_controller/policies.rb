module MiqPolicyController::Policies
  extend ActiveSupport::Concern

  def policy_edit
    case params[:button]
    when "cancel"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("policy_edit__#{id}","replace_cell__explorer")
      @policy = MiqPolicy.find_by_id(@edit[:policy_id]) if @edit[:policy_id]
      if @policy && @policy.id
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"MiqPolicy"), :name=>@policy.description})
      else
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"MiqPolicy"))
      end
      @edit = nil
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      @sb[:action] = "policy_edit"
      policy_build_edit_screen(session[:edit] ? session[:edit][:typ] : params[:typ])
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("p")
      return
    end

    # Load @edit/vars for other buttons
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("policy_edit__#{id}","replace_cell__explorer")
    @policy = @edit[:policy_id] ? MiqPolicy.find_by_id(@edit[:policy_id]) : MiqPolicy.new

    case params[:button]
    when "save", "add"
      assert_privileges("policy_#{@policy.id ? "edit" : "new"}")
      policy = @policy.id.blank? ? MiqPolicy.new : MiqPolicy.find(@policy.id) # Get new or existing record
      policy.mode = @edit[:new][:mode]
      policy.towhat = @edit[:new][:towhat] if @policy.id.blank?               # Set model if new record
      policy.created_by = session[:userid] if @policy.id.blank?               # Set created user if new record
      policy.updated_by = session[:userid]
      case @edit[:typ]
      when "basic"
        policy.description = @edit[:new][:description]
        policy.active = @edit[:new][:active]
        policy.notes = @edit[:new][:notes]
        policy.expression = @edit[:new][:expression]["???"] ? nil : MiqExpression.new(@edit[:new][:expression])
      when "conditions"
        mems = @edit[:new][:conditions].invert                  # Get the ids from the member list box
        policy.conditions.collect{|pc|pc}.each{|c| policy.conditions.delete(c) unless mems.keys.include?(c.id) }  # Remove any conditions no longer in members
        mems.each_key {|m| policy.conditions.push(Condition.find(m)) unless policy.conditions.collect(&:id).include?(m) }    # Add any new conditions
      end
      if policy.valid? && !@flash_array && policy.save
        if @policy.id.blank? && policy.mode == "compliance"   # New compliance policy
          event = MiqEvent.find_by_name("#{policy.towhat.downcase}_compliance_check") # Get the compliance event record
          policy.sync_events([event])                           # Set the default compliance event in the policy
          action_list = [[MiqAction.find_by_name("compliance_failed"), {:qualifier=>:failure, :synchronous=>true}]]
          policy.replace_actions_for_event(event, action_list)  # Add in the default action for the compliance event
        end
        policy.sync_events(@edit[:new][:events].collect{|e| MiqEvent.find(e)}) if @edit[:typ] == "events"
        AuditEvent.success(build_saved_audit(policy, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") :
                                                _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "MiqPolicy"), :name => @edit[:new][:description]})
        policy_get_info(MiqPolicy.find(policy.id))
        @edit = nil
        @nodetype = "p"
        case x_active_tree
        when :policy_profile_tree
          replace_right_cell("p", [:policy_profile, :policy])
        when :policy_tree
          @nodetype = "p"
          if params[:button] == "add"
            self.x_node = @new_policy_node = "xx-#{policy.mode.downcase}_xx-#{policy.mode.downcase}-#{policy.towhat.downcase}_p-#{to_cid(policy.id)}"
            get_node_info(@new_policy_node)
          end
          replace_right_cell("p", params[:button] == "save" ? [:policy_profile, :policy] : [:policy])
        end
      else
        policy.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("p")
      end
    when "move_right", "move_left", "move_allleft"
      handle_selection_buttons(:conditions)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("p")
    end
  end

  # Copy a policy
  def policy_copy
    assert_privileges("policy_copy")
    policy = MiqPolicy.find(params[:id])
    new_desc = truncate("Copy of #{policy.description}", :length => 255, :omission => "")
    if MiqPolicy.find_by_description(new_desc)
      add_flash(_("%{model} \"%{name}\" already exists") % {:model=>ui_lookup(:model=>"MiqPolicy"), :name=>new_desc}, :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    else
      new_pol = policy.copy(:description=>new_desc, :created_by=>session[:userid])
      AuditEvent.success({:event=>"miqpolicy_copy",
                          :target_id=>new_pol.id,
                          :target_class=>"MiqPolicy",
                          :userid => session[:userid],
                          :message=>"New Policy ID #{new_pol.id} was copied from Policy ID #{policy.id}"})
      add_flash(_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"MiqPolicy"), :name=>new_desc})
      @new_policy_node = "xx-#{policy.mode.downcase}_xx-#{policy.mode.downcase}-#{policy.towhat.downcase}_p-#{to_cid(policy.id)}"
      get_node_info(@new_policy_node)
      replace_right_cell("p", [:policy])
    end
  end

  def policy_delete
    assert_privileges("policy_delete")
    policies = Array.new
    # showing 1 policy, delete it
    pol = MiqPolicy.find_by_id(params[:id])
    if params[:id] == nil || pol.nil?
      add_flash(_("%s no longer exists") % ui_lookup(:model=>"MiqPolicy"),
                  :error)
    else
      policies.push(params[:id])
      self.x_node = @new_policy_node = "xx-#{pol.mode.downcase}_xx-#{pol.mode.downcase}-#{pol.towhat.downcase}"
    end
    process_policies(policies, "destroy") unless policies.empty?
    add_flash(_("The selected %s was deleted") % ui_lookup(:models=>"MiqPolicy")) if @flash_array == nil
    get_node_info(@new_policy_node)
    replace_right_cell("xx", [:policy, :policy_profile])
  end

  def policy_field_changed
    return unless load_edit("policy_edit__#{params[:id]}","replace_cell__explorer")
    @profile = @edit[:profile]

    case @edit[:typ]
    when "basic"
      @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
      @edit[:new][:notes] = params[:notes].blank? ? nil : params[:notes] if params[:notes]
      @edit[:new][:active] = (params[:active] == "1") if params.has_key?(:active)
    when "events"
      params.keys.each do |field|
        if field.to_s.starts_with?("event_")
          event = field.to_s.split("_").last
          if params[field] == "1"
            @edit[:new][:events].push(event)      # Add event to array
          else
            @edit[:new][:events].delete(event)    # Delete event from array
          end
        end
        @edit[:new][:events].uniq!
        @edit[:new][:events].sort!
      end
    end

    send_button_changes
  end

  def policy_get_all
    peca_get_all('policy', lambda { get_view(MiqPolicy, :conditions=>["mode = ? and towhat = ?", @sb[:mode].downcase, @sb[:nodeid].titleize]) } )
  end

  private

  def process_policies(policies, task)
    process_elements(policies, MiqPolicy, task)
  end

  def policy_build_edit_screen(edit_type = nil)
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @policy = params[:id] ? MiqPolicy.find(params[:id]) : MiqPolicy.new                   # Get existing or new record
    @edit[:key] = "policy_edit__#{@policy.id || "new"}"
    @mode = params[:id] ? @policy.mode.capitalize : x_node.split("_").first.split("-").last
    @edit[:rec_id] = @policy.id || nil

    @edit[:typ] = edit_type                                                               # Remember edit type (basic/events/conditions)
    @edit[:policy_id] = @policy.id
    @edit[:new][:mode] = params[:id] ? @policy.mode : @mode.downcase                      # Get mode from record or folder
    @edit[:new][:description] = @policy.description
    @edit[:new][:active] = @policy.active.nil? ? true : @policy.active                    # Set active, default to true
    @edit[:new][:notes] = @policy.notes
    @edit[:new][:towhat] = @policy.id ? @policy.towhat : @sb[:folder].split('-').last.titleize                    # Set the towhat model

    case @edit[:typ]  # Build fields based on what is being edited
    when "conditions" # Editing condition assignments
      @edit[:new][:conditions] = Hash.new
      conditions = @policy.conditions     # Get the condittions
      conditions.each{|c| @edit[:new][:conditions][c.description] = c.id}   # Build a hash for the members list box

      @edit[:choices] = Hash.new
      Condition.find_all_by_towhat(@edit[:new][:towhat]).each {|c| @edit[:choices][c.description] = c.id} # Build a hash for the policies to choose from

      @edit[:new][:conditions].each_key{|key| @edit[:choices].delete(key)}  # Remove any choices that are in the members list box
    when "events" # Editing event assignments
      @edit[:new][:events] = @policy.miq_events.collect{|e| e.id.to_s}.uniq.sort

      @edit[:allevents] = {}
      MiqPolicy.all_policy_events.each do |e|
        next if excluded_event?(e)
        @edit[:allevents][e.etype.description] ||= []
        @edit[:allevents][e.etype.description].push([e.description, e.id.to_s])
      end
    else  # Editing basic information and policy scope
      build_expression(@policy, @edit[:new][:towhat])
    end

    @edit[:current] = copy_hash(@edit[:new])

    @embedded = true            # don't show flash msg or check boxes in Policies partial
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:policy_id].nil?                              # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def excluded_event?(event)
    event.name.end_with?("compliance_check") ||
    event.name.end_with?("perf_complete")
  end

  def policy_get_all_folders(parent = nil)
    if parent != nil
      @folders = ["Host", "Vm"]
      @right_cell_text = _("%{typ} %{model}") % {:typ=>parent, :model=>ui_lookup(:models=>"MiqPolicy")}
      @right_cell_div = "policy_folders"
    else
      @folders = ["Compliance", "Control"]
      @right_cell_text = _("All %s") % ui_lookup(:models=>"MiqPolicy")
      @right_cell_div = "policy_folders"
    end
  end

  # Get information for a policy
  def policy_get_info(policy)
    @record = @policy = policy
    @right_cell_text = _("%{model} \"%{name}\"") % {:model=>"#{ui_lookup(:model=>@sb[:folder])} #{@sb[:mode]} Policy", :name=>@policy.description.gsub(/'/,"\\'")}
    @right_cell_div = "policy_details"
    @policy_conditions = @policy.conditions
    @policy_events = @policy.miq_events
    @expression_table = @policy.expression.is_a?(MiqExpression) ? exp_build_table(@policy.expression.exp) : nil

    if x_active_tree == :policy_tree
      @policy_profiles = @policy.memberof.sort{|a,b|a.description.downcase<=>b.description.downcase}
    end
  end

  def policy_build_tree(type=:policy, name=:policy_tree)
    x_tree_init(name, type, 'MiqPolicy', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root = tree_nodes.first
    root[:title] = "All Policies"
    root[:tooltip] = "All Policies"
    root[:icon] = "folder.png"

    @temp[name] = tree_nodes.to_json  # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)    # Set active node to root if not set
  end

end
