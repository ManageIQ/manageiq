module MiqPolicyController::Rsop
  extend ActiveSupport::Concern

  def rsop
    @explorer = true
    @collapse_c_cell = true
    if params[:button] == "submit"
      unless params[:task_id]                       # First time thru, kick off the report generate task
        case @sb[:rsop][:filter]
        when "vm"
          vms = [Vm.find(@sb[:rsop][:filter_value])]
        when "ems"
          vms = ExtManagementSystem.find(@sb[:rsop][:filter_value]).find_filtered_children("vms")
        when "cluster"
          vms = EmsCluster.find(@sb[:rsop][:filter_value]).find_filtered_children("all_vms")
        when "host"
          vms = Host.find(@sb[:rsop][:filter_value]).find_filtered_children("vms")
        end
        if vms.length > 0
          @sb[:rsop][:out_of_scope] = true
          @sb[:rsop][:passed] = true
          @sb[:rsop][:failed] = true
          @sb[:rsop][:open] = false
          initiate_wait_for_task(:task_id => Vm.rsop_async(MiqEventDefinition.find(@sb[:rsop][:event_value]), vms))
          return
        else
          add_flash(_("No VMs match the selection criteria"), :error)
        end
      else
        miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
        if miq_task.task_results.blank?               # Check to see if any results came back
          add_flash(_("Policy Simulation generation returned: %{error_message}") % {:error_message => miq_task.message}, :error)
        else
          @sb[:rsop][:results] = miq_task.task_results
          session[:rsop_tree] = rsop_build_tree
        end
      end
      c_tb = build_toolbar(center_toolbar_filename)
      render :update do |page|
        page << javascript_prologue
        page.replace_html("main_div", :partial => "rsop_results")
        page << javascript_pf_toolbar_reload('center_tb', c_tb)
        page << "miqSparkle(false);"
      end
    elsif params[:button] == "reset"
      @sb[:rsop] = {}     # Reset all RSOP stored values
      session[:changed] = session[:rsop_tree] = nil
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'rsop'
      end
    else  # No params, first time in
      @breadcrumbs = []
      @accords = [{:name => "rsop", :title => "Options", :container => "rsop_options_div"}]
      session[:changed] = false
      @sb[:rsop] ||= {}   # Leave exising values
      rsop_put_objects_in_sb(find_filtered(ExtManagementSystem), :emss)
      rsop_put_objects_in_sb(find_filtered(EmsCluster), :clusters)
      rsop_put_objects_in_sb(find_filtered(Host), :hosts)
      rsop_put_objects_in_sb(find_filtered(Vm), :vms)
      rsop_put_objects_in_sb(find_filtered(Storage), :datastores)
      @rsop_events = MiqEventDefinitionSet.all.collect { |e| [e.description, e.id.to_s] }.sort
      @rsop_event_sets = MiqEventDefinitionSet.find(@sb[:rsop][:event]).miq_event_definitions.collect { |e| [e.description, e.id.to_s] }.sort unless @sb[:rsop][:event].nil?
      render :layout => "application"
    end
  end

  def rsop_option_changed
    if params[:event_typ]
      @sb[:rsop][:event] = params[:event_typ] == "<Choose>" ? nil : params[:event_typ]
      @sb[:rsop][:event_value] = nil
    end
    if params[:event_value]
      @sb[:rsop][:event_value] = params[:event_value] == "<Choose>" ? nil : params[:event_value]
    end
    if params[:filter_typ]
      @sb[:rsop][:filter] = params[:filter_typ] == "<Choose>" ? nil : params[:filter_typ]
      @sb[:rsop][:filter_value] = nil
    end
    if params[:filter_value]
      @sb[:rsop][:filter_value] = params[:filter_value] == "<Choose>" ? nil : params[:filter_value]
    end
    @rsop_events = MiqEventDefinitionSet.all.collect { |e| [e.description, e.id.to_s] }.sort
    @rsop_event_sets = MiqEventDefinitionSet.find(@sb[:rsop][:event]).miq_event_definitions.collect { |e| [e.description, e.id.to_s] }.sort unless @sb[:rsop][:event].nil?
    render :update do |page|
      page << javascript_prologue
      session[:changed] = @sb[:rsop][:filter_value] && @sb[:rsop][:event_value] ? true : false
      page.replace("rsop_form_div", :partial => "rsop_form")
      if session[:changed]
        page << javascript_hide("form_buttons_off")
        page << javascript_show("form_buttons_on")
      else
        page << javascript_hide("form_buttons_on")
        page << javascript_show("form_buttons_off")
      end
    end
  end

  def rsop_toggle
    @explorer = true
    @sb[:rsop][:open] = @sb[:rsop][:open] != true # set this before creating toolbar
    rsop_button_pressed
  end

  def rsop_show_options
    @explorer = true
    if params.key?(:passed)
      if params[:passed] == "null" || params[:passed] == ""
        @sb[:rsop][:passed] = false
        @sb[:rsop][:failed] = true
      else
        @sb[:rsop][:passed] = true
      end
    end
    if params.key?(:failed)
      if params[:failed] == "null" || params[:failed] == ""
        @sb[:rsop][:passed] = true
        @sb[:rsop][:failed] = false
      else
        @sb[:rsop][:failed] = true
      end
    end
    if params[:out_of_scope]
      @sb[:rsop][:out_of_scope] = (params[:out_of_scope] == "1")
    end
    @sb[:rsop][:open] = false           # reset the open state to select correct button in toolbar, need to replace partial to update checkboxes in form
    session[:rsop_tree] = rsop_build_tree
    rsop_button_pressed
  end

  private

  def rsop_put_objects_in_sb(objects, key)
    @sb[:rsop][key] = {}
    objects
      .sort_by { |o| o.name.downcase }
      .each { |o| @sb[:rsop][key][o.id.to_s] = o.name }
  end

  def rsop_button_pressed
    c_tb = build_toolbar(center_toolbar_filename)
    render :update do |page|
      page << javascript_prologue
      if params[:action] == "rsop_toggle"
        if @sb[:rsop][:open] == true
          page << "miqDynatreeToggleExpand('rsop_tree', true);"
        else
          page << "miqDynatreeToggleExpand('rsop_tree', false)"
          page << "miqDynatreeActivateNodeSilently('rsop_tree', 'rsoproot');"
          @sb[:rsop][:results].each do |r|
            page << "miqDynatreeExpandNode('rsop_tree', 'rsoproot-v_#{r[:id]}');"
          end
        end
      else
        # if rsop_show_options came in
        page.replace_html("main_div", :partial => "rsop_results")
      end
      page << javascript_pf_toolbar_reload('center_tb', c_tb)
    end
  end

  def rsop_build_tree
    event = MiqEventDefinition.find(@sb[:rsop][:event_value])
    root_node = TreeNodeBuilder.generic_tree_node(
      "rsoproot",
      _("Policy Simulation Results for Event [%{description}]") % {:description => event.description},
      "event-#{event.name}.png",
      "",
      :style_class => "cfme-no-cursor-node",
      :expand      => true
    )

    top_nodes = []
    @sb[:rsop][:results].sort_by { |a| a[:name].downcase }.each do |r|
      top_nodes.push(rsop_tree_add_node(r, root_node[:key]))
    end
    root_node[:children] = top_nodes unless top_nodes.empty?
    root_node.to_json
  end

  # Build add tree node
  def rsop_tree_add_node(node, pid, nodetype = "v")
    unless ["v", "s", "e"].include?(nodetype) # Always show VMs, scopes, and expressions
      return nil if @sb[:rsop][:out_of_scope] == false && node['result'] == "N/A"  # Skip out of scope item
      if nodetype == "p"  # Skip unchecked policies
        return nil if @sb[:rsop][:passed] == false && node['result'] != "deny"
        return nil if @sb[:rsop][:failed] == false && node['result'] == "deny"
      end
    end
    key     = "#{pid}-#{nodetype}_#{(node[:id] ? node[:id].to_s : '0')}"  # If no id, use 0
    icon    = "x.png"
    icon    = "checkmark.png" if node[:result] == "allow"
    icon    = "na.png" if node[:result] == "N/A"
    expand  = false
    tooltip = ""
    style   = "cfme-no-cursor-node"

    t_kids = []                          # Array to hold node children
    case nodetype
    when "v"
      title = "<strong>VM:</strong> #{node[:name]}"
      icon = "vm.png"
      expand = true
      node[:profiles].each do |pp|
        nn = rsop_tree_add_node(pp, key, "pp")
        t_kids.push(nn) unless nn.nil?
      end
    when "pp"
      title = "<strong>#{_('Profile:')}</strong> #{node[:description]}"
      expand = false
      node[:policies].sort_by { |a| a[:description].downcase }.each do |p|
        nn = rsop_tree_add_node(p, key, "p")
        t_kids.push(nn) unless nn.nil?
      end
    when "p"
      active_caption = node[:active] ? "" : "(Inactive)"
      title = "<strong>Policy#{active_caption}:</strong> #{node[:description]}"
      expand = false
      t_kids.push(rsop_tree_add_node(node[:scope], key, "s")) if node[:scope]
      node[:conditions].sort_by { |a| a[:description].downcase }.each_with_index do |c, _i|
        nn = rsop_tree_add_node(c, key, "c")
        t_kids.push(nn) unless nn.nil?
      end
      node[:actions].each_with_index do |a, _i|
        nn = rsop_tree_add_node(a, key, "a")
        t_kids.push(nn) unless nn.nil?
      end
    when "c"
      title = "<strong>#{_('Condition:')}</strong> #{node[:description]}"
      expand = false
      t_kids.push(rsop_tree_add_node(node[:scope], key, "s")) if node[:scope]
      t_kids.push(rsop_tree_add_node(node[:expression], key, "e")) if node[:expression]
    when "a"
      title = "<strong>#{_('Action:')}</strong> #{node[:description]}"
      expand = false
    when "s"
      icon = node[:result] == true ? "checkmark.png" : "na.png"
      s_text, s_tip = exp_build_string(node)
      title = "<style>span.ws-wrap { white-space: normal; }</style>
        <strong>#{_('Scope:')}</strong> <span class='ws-wrap'>#{s_text}"
      tooltip = s_tip
      expand = false
    when "e"
      icon = "na.png"
      icon = "checkmark.png" if node["result"] == true
      icon = "x.png" if node["result"] == false
      e_text, e_tip = exp_build_string(node)
      title = "<style>span.ws-wrap { white-space: normal; }</style>
        <strong>#{_('Expression')}:</strong> <span class='ws-wrap'>#{e_text}"
      tooltip = e_tip
      expand = false
    end
    t_node = TreeNodeBuilder.generic_tree_node(
      key,
      title.html_safe,
      icon,
      tooltip,
      :expand      => expand,
      :style_class => style
    )
    t_node[:children] = t_kids unless t_kids.empty?              # Add in the node's children, if any
    t_node
  end
end
