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
          count = 1
        when "ems"
          vms, count = ExtManagementSystem.find(@sb[:rsop][:filter_value]).find_filtered_children("vms")
        when "cluster"
          vms, count = EmsCluster.find(@sb[:rsop][:filter_value]).find_filtered_children("all_vms")
        when "host"
          vms, count = Host.find(@sb[:rsop][:filter_value]).find_filtered_children("vms")
        end
        if count > 0
          @sb[:rsop][:out_of_scope] = true
          @sb[:rsop][:passed] = true
          @sb[:rsop][:failed] = true
          @sb[:rsop][:open] = false
          initiate_wait_for_task(:task_id => Vm.rsop_async(MiqEvent.find(@sb[:rsop][:event_value]), vms))
          return
        else
          add_flash(I18n.t("flash.policy.no_vm_match"), :error)
        end
      else
        miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
        if miq_task.task_results.blank?               # Check to see if any results came back
          add_flash(I18n.t("flash.policy.simulation_generation_error") << miq_task.message, :error)
        else
          @sb[:rsop][:results] = miq_task.task_results
          session[:rsop_tree] = rsop_build_tree
        end
      end
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
      render :update do |page|
        page.replace_html("main_div", :partial=>"rsop_results")
        if c_buttons && c_xml
          page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
          page << "$('center_buttons_div').show();"
        else
          page << "$('center_buttons_div').hide();"
        end
        page << "miqSparkle(false);"
      end
    elsif params[:button] == "reset"
      @sb[:rsop] = Hash.new     # Reset all RSOP stored values
      session[:changed] = session[:rsop_tree] = nil
      render :update do |page|  # Redraw the screen
        page.redirect_to :action => 'rsop'
      end
    else  # No params, first time in
      @breadcrumbs = Array.new
      @accords = [{:name=>"rsop", :title=>"Options", :container=>"rsop_options_div"}]
      @sb[:rsop] ||= Hash.new   # Leave exising values
      @sb[:rsop][:emss] = Hash.new
      find_filtered(ExtManagementSystem, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:rsop][:emss][e.id.to_s] = e.name}
      @sb[:rsop][:clusters] = Hash.new
      find_filtered(EmsCluster, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:rsop][:clusters][e.id.to_s] = e.name}
      @sb[:rsop][:hosts] = Hash.new
      find_filtered(Host, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:rsop][:hosts][e.id.to_s] = e.name}
      @sb[:rsop][:vms] = Hash.new
      find_filtered(Vm, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:rsop][:vms][e.id.to_s] = e.name}
      @sb[:rsop][:datastores] = Hash.new
      find_filtered(Storage, :all).sort{|a,b| a.name.downcase<=>b.name.downcase}.each{|e|@sb[:rsop][:datastores][e.id.to_s] = e.name}
      @temp[:rsop_events] = MiqEventSet.all.collect{|e|[e.description, e.id.to_s]}.sort
      @temp[:rsop_event_sets] = MiqEventSet.find(@sb[:rsop][:event]).miq_events.collect{|e|[e.description, e.id.to_s]}.sort if @sb[:rsop][:event] != nil
      render :layout => "explorer"
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
    @temp[:rsop_events] = MiqEventSet.all.collect{|e|[e.description, e.id.to_s]}.sort
    @temp[:rsop_event_sets] = MiqEventSet.find(@sb[:rsop][:event]).miq_events.collect{|e|[e.description, e.id.to_s]}.sort if @sb[:rsop][:event] != nil
    render :update do |page|                    # Use JS to update the display
      session[:changed] = @sb[:rsop][:filter_value] && @sb[:rsop][:event_value] ? true : false
      page.replace("rsop_form_div", :partial=>"rsop_form")
      if session[:changed]
        page << "$('form_buttons_off').hide();"
        page << "$('form_buttons_on').show();"
      else
        page << "$('form_buttons_on').hide();"
        page << "$('form_buttons_off').show();"
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
    if params.has_key?(:passed)
      if params[:passed] == "null" || params[:passed] == ""
        @sb[:rsop][:passed] = false
        @sb[:rsop][:failed] = true
      else
        @sb[:rsop][:passed] = true
      end
    end
    if params.has_key?(:failed)
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
    @sb[:rsop][:open] = false           #reset the open state to select correct button in toolbar, need to replace partial to update checkboxes in form
    session[:rsop_tree] = rsop_build_tree
    rsop_button_pressed
  end

  private

  def rsop_button_pressed
    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    render :update do |page|
      if params[:action] == "rsop_toggle"
        if @sb[:rsop][:open] == true
          page << "cfme_dynatree_toggle_expand('rsop_tree', true);"
        else
          page << "cfme_dynatree_toggle_expand('rsop_tree', false)"
          page << "cfmeDynatree_activateNodeSilently('rsop_tree', 'rsoproot');"
          @sb[:rsop][:results].each do |r|
            page << "cfmeDynatree_expandNode('rsop_tree', 'rsoproot-v_#{r[:id]}');"
          end
        end
      else
        # if rsop_show_options came in
        page.replace_html("main_div", :partial=>"rsop_results")
      end
      if c_buttons && c_xml
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << "$('center_buttons_div').show();"
      else
        page << "$('center_buttons_div').hide();"
      end
    end
  end

  def rsop_build_tree
    event = MiqEvent.find(@sb[:rsop][:event_value])
    root_node = TreeNodeBuilder.generic_tree_node(
      "rsoproot",
      "Policy Simulation Results for Event [#{event.description}]",
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
  def rsop_tree_add_node(node, pid, nodetype="v")
    unless ["v", "s", "e"].include?(nodetype) # Always show VMs, scopes, and expressions
      return nil if @sb[:rsop][:out_of_scope] == false  && node['result'] == "N/A"  # Skip out of scope item
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
      title = "<strong>Profile:</strong> #{node[:description]}"
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
      node[:conditions].sort_by { |a| a[:description].downcase }.each_with_index do |c, i|
        nn = rsop_tree_add_node(c, key, "c")
        t_kids.push(nn) unless nn.nil?
      end
      node[:actions].each_with_index do |a, i|
        nn = rsop_tree_add_node(a, key, "a")
        t_kids.push(nn) unless nn.nil?
      end
    when "c"
      title = "<strong>Condition:</strong> #{node[:description]}"
      expand = false
      t_kids.push(rsop_tree_add_node(node[:scope], key, "s")) if node[:scope]
      t_kids.push(rsop_tree_add_node(node[:expression], key, "e")) if node[:expression]
    when "a"
      title = "<strong>Action:</strong> #{node[:description]}"
      expand = false
    when "s"
      icon = node[:result] == true ? "checkmark.png" : "na.png"
      s_text, s_tip = exp_build_string(node)
      title = "<style>span.ws-wrap { white-space: normal; }</style>
        <strong>Scope:</strong> <span class='ws-wrap'>#{s_text}"
      tooltip = s_tip
      expand = false
    when "e"
      icon = "na.png"
      icon = "checkmark.png" if node["result"] == true
      icon = "x.png" if node["result"] == false
      e_text, e_tip = exp_build_string(node)
      title = "<style>span.ws-wrap { white-space: normal; }</style>
        <strong>Expression:</strong> <span class='ws-wrap'>#{e_text}"
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
