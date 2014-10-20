module MiqPolicyController::Events
  extend ActiveSupport::Concern

  def event_edit
    assert_privileges("event_edit")
    case params[:button]
    when "cancel"
      @edit = nil
      add_flash(I18n.t("flash.policy.task_cancelled_by_user", :task=>"Edit Event"))
      get_node_info(x_node)
      replace_right_cell(@nodetype)
      return
    when "reset", nil # Reset or first time in
      event_build_edit_screen
      @sb[:action] = "event_edit"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("ev")
      return
    end

    # Reload @edit/vars for other buttons
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("event_edit__#{id}","replace_cell__explorer")
    @event = @edit[:event_id] ? MiqEvent.find_by_id(@edit[:event_id]) : MiqEvent.new
    policy = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"]))
    @temp[:policy] = policy

    case params[:button]
    when "save"
      event = MiqEvent.find(@event.id)                        # Get event record
      action_list = @edit[:new][:actions_true].collect{|a| [MiqAction.find(a.last), {:qualifier=>:success, :synchronous=>a[1]}]} +
                    @edit[:new][:actions_false].collect{|a| [MiqAction.find(a.last), {:qualifier=>:failure, :synchronous=>a[1]}]}
      policy.replace_actions_for_event(event, action_list)
      AuditEvent.success(build_saved_audit(event))
      add_flash(I18n.t("flash.policy.policy_event_actions_saved", :name=>event.description))
      @nodetype = "ev"
      event_get_info(MiqEvent.find(event.id))
      @edit = nil
      replace_right_cell("ev", [:policy_profile, :policy])
    when "true_right", "true_left", "true_allleft", "true_up", "true_down", "true_sync", "true_async"
      handle_selection_buttons(:actions_true, :members_chosen_true, :choices_true, :choices_chosen_true)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("ev")
    when "false_right", "false_left", "false_allleft", "false_up", "false_down", "false_sync", "false_async"
      handle_selection_buttons(:actions_false, :members_chosen_false, :choices_false, :choices_chosen_false)
      session[:changed] = (@edit[:new] != @edit[:current])
      replace_right_cell("ev")
    end
  end

  private

  def event_build_edit_screen
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @event = MiqEvent.find(params[:id])                                         # Get event record
    policy = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"]))   # Get the policy above this event
    @temp[:policy] = policy                                 # Save for use in the view
    @edit[:key] = "event_edit__#{@event.id || "new"}"
    @edit[:rec_id] = @event.id || nil

    @edit[:event_id] = @event.id

    @edit[:new][:actions_true] = Array.new
    policy.actions_for_event(@event, :success).each do |as| # Build true actions array
      sync = as.synchronous == nil || as.synchronous
      @edit[:new][:actions_true].push([(sync ? "(S) " : "(A) ") + as.description, sync, as.id])
    end

    @edit[:new][:actions_false] = Array.new
    policy.actions_for_event(@event, :failure).each do |af|                     # Build false actions array
      sync = af.synchronous == nil || af.synchronous
      @edit[:new][:actions_false].push([(sync ? "(S) " : "(A) ") + af.description, sync, af.id])
    end

    @edit[:choices_true] = Hash.new                         # Build a new choices list for true actions
    MiqAction.all.each { |a|                          # Build a hash for the true choices
      @edit[:choices_true][a.description] =  a.id
    }
    @edit[:new][:actions_true].each { |as|
      @edit[:choices_true].delete(as[0].slice(4..-1))       # Remove any choices already in the list (desc is first element, but has "(x) " in front)
    }

    @edit[:choices_false] = Hash.new                        # Build a new choices list for false actions
    MiqAction.all.each { |a|                          # Build a hash for the false choices
      @edit[:choices_false][a.description] =  a.id
    }
    @edit[:new][:actions_false].each { |as|
      @edit[:choices_false].delete(as[0].slice(4..-1))      # Remove any choices already in the list (desc is first element, but has "(x) " in front)
    }

    @edit[:current] = copy_hash(@edit[:new])

    @embedded = true
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:event_id].nil?                       # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def event_get_all
    @events = MiqPolicy.all_policy_events.sort{|a,b|a.description.downcase<=>b.description.downcase}
    set_search_text
    @events = apply_search_filter(@search_text, @events) if !@search_text.blank?
    @right_cell_text = I18n.t("cell_header.all_model_records",:model=>ui_lookup(:tables=>"miq_event"))
    @right_cell_div = "event_list"
  end

  # Get information for an event
  def event_get_info(event)
    @record = @event = event
    @temp[:policy] = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"])) unless x_active_tree == :event_tree
    @right_cell_text = I18n.t("cell_header.model_record",:model=>ui_lookup(:tables=>"miq_event"),:name=>event.description)
    @right_cell_div = "event_details"

    if x_active_tree == :event_tree
      @event_policies = @event.miq_policies.sort{|a,b|a.description.downcase<=>b.description.downcase}
    else
      @event_true_actions = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"])).actions_for_event(event, :success)
      @event_false_actions = MiqPolicy.find(from_cid(@sb[:node_ids][x_active_tree]["p"])).actions_for_event(event, :failure)
    end
  end

  def event_build_tree(type=:event, name=:event_tree)
    x_tree_init(name, type, 'MiqEvent', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root = tree_nodes.first
    root[:title] = "All Events"
    root[:tooltip] = "All Events"
    root[:icon] = "folder.png"

    @temp[name] = tree_nodes.to_json  # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)    # Set active node to root if not set
  end

end
