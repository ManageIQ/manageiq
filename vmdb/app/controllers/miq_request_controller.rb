class MiqRequestController < ApplicationController

  before_filter :check_privileges, :except => :post_install_callback
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  helper CloudResourceQuotaHelper

  def index
#   show_list
#   render :action=>"show_list"
    @request_tab = params[:typ] if params[:typ]                       # set this to be used to identify which Requests subtab was clicked
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    params[:page] = @current_page if @current_page != nil # Save current page for list refresh
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    deleterequests if params[:pressed] == "miq_request_delete"
    request_edit if params[:pressed] == "miq_request_edit"
    request_copy if params[:pressed] == "miq_request_copy"

    if ! @refresh_partial && params[:pressed] != "miq_request_reload" # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
    return if params[:pressed] == "miq_request_edit" && @refresh_partial == "reconfigure"
    if !@flash_array.nil? && params[:pressed] == "miq_request_delete"
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif ["miq_request_copy","miq_request_edit"].include?(params[:pressed])
      render :update do |page|
        page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :req_id=>@req_id, :org_controller=>@org_controller
      end
    elsif params[:pressed].ends_with?("_edit")
      if @refresh_partial == "show_list"
        render :update do |page|
          page.redirect_to :action =>@refresh_partial, :flash_msg=>"Default Requests can not be edited", :flash_error=>true
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    elsif params[:pressed] == "miq_request_reload"
      if @display == "main" && params[:id].present?
        show
        c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
        render :update do |page|
          page.replace("request_div", :partial => "miq_request/request")
          page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
          page << javascript_show("center_buttons_div")
        end
      elsif @display == "miq_provisions"
        show
        render :update do |page|
          page.replace("gtl_div", :partial=>"layouts/gtl")  # Replace the provisioned vms list
        end
      else
        #forcing to refresh the view when reload button is pressed
        @_params[:refresh] = "y"
        show_list
        render :update do |page|
          page.replace("prov_options_div", :partial=>"prov_options")
          page.replace("gtl_div", :partial=>"layouts/gtl")
        end
      end
    else
      render :update do |page|                    # Use RJS to update the display
        if @refresh_partial != nil
          if @refresh_div == "flash_msg_div"
            page.replace(@refresh_div, :partial=>@refresh_partial)
          else
            page.replace_html(@refresh_div, :partial=>@refresh_partial)
          end
        end
        page.replace_html(@refresh_div, :action=>@render_action) if @render_action != nil
      end
    end
  end

  def request_edit
    assert_privileges("miq_request_edit")
    prov = MiqRequest.find_by_id(params[:id])
    if prov.workflow_class
      @org_controller = prov.resource_type == "MiqHostProvisionRequest" ? "host" : "vm"                           #request originated for resource_type
      @redirect_controller = "miq_request"
      @refresh_partial = "prov_edit"
      @req_id = params[:id]
      @prov_type = prov.resource_type
    else
      session[:checked_items] = prov.options[:src_ids]
      @refresh_partial = "reconfigure"
      @_params[:controller] = "vm"
      reconfigurevms
    end
  end

  def request_copy
    assert_privileges("miq_request_copy")
    prov = MiqRequest.find_by_id(params[:id])
    @redirect_controller = "miq_request"
    @refresh_partial = "prov_copy"
    @org_controller = prov.kind_of?(MiqHostProvisionRequest) ? "host" : "vm"                            #request originated for resource_type
    @req_id = params[:id]
    @prov_type = prov.resource_type
  end

  # Show the main Requests list view
  def show_list
    @breadcrumbs = Array.new
    bc_name = "Requests"
    @request_tab = params[:typ] if params[:typ]                       # set this to be used to identify which Requests subtab was clicked
    case @request_tab
    when "vm"
      @layout = "miq_request_vm"
    when "host"
      @layout = "miq_request_host"
    when "ae"
      @layout = "miq_request_ae"
    else
      @layout = "miq_request_vm"
    end
    drop_breadcrumb( {:name=>bc_name, :url=>"/miq_request/show_list?typ=#{@request_tab}"} )
    @lastaction = "show_list"
    @gtl_url = "/miq_request/show_list/?"

    @settings[:views][:miqrequest] = params[:type] if params[:type]   # new gtl type came in, set it
    @gtl_type = @settings[:views][:miqrequest]                        # set the var for the UI to use

    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][PERPAGE_TYPES[@gtl_type]] = @items_per_page # Set the per page setting for this gtl type
    end
    @sortcol = session[:request_sortcol] == nil ? 0 : session[:request_sortcol].to_i
    @sortdir = session[:request_sortdir] == nil ? "ASC" : session[:request_sortdir]
    @listicon = "miq_request"
    @no_checkboxes = true   # Don't show checkboxes, read_only
#   @showlinks = true
    time_period = 7
    resource_type = get_request_tab_type        # storing resource type in local variable so dont have to call method everytime
    kls = @layout == "miq_request_ae" ? AutomationRequest : MiqRequest
    if is_approver && (!@sb[:prov_options] || (@sb[:prov_options] && !@sb[:prov_options].has_key?(resource_type.to_sym)))
      gv_options = {:filter=>prov_condition({:resource_type=>resource_type,:time_period=>time_period})}
      @view, @pages = get_view(kls, gv_options)                 # Get all requests
    elsif @sb[:prov_options] && @sb[:prov_options].has_key?(resource_type.to_sym) # added this here so grid can be drawn when page redraws, when there were no records on initial load.
      prov_set_default_options if @sb[:def_prov_options][:applied_states].blank? && !params[:button] == "apply" # no filter statuses selected, setting to default
      gv_options = {:filter=>prov_condition(@sb[:def_prov_options][resource_type.to_sym])}
      @view, @pages = get_view(kls, gv_options) # Get view and paginator, based on the selected options
    else
      requester = User.find_by_userid(session[:userid])
      gv_options = {:filter=>prov_condition({:resource_type=>resource_type, :time_period=>time_period, :requester_id=>requester ? requester.id : nil})}
      @view, @pages = get_view(kls, gv_options)     # Get requests for this user
    end
    @sb[:prov_options] ||= Hash.new
    @sb[:def_prov_options] ||= Hash.new
    @sb[:prov_options][:resource_type] = resource_type.to_sym                   # storing current resource type
    #prov_set_default_options if !@sb[:prov_options] || (@sb[:prov_options] && @sb[:prov_options][:req_typ] != get_request_tab_type)    # reset default options if requests sub tab has changed
    prov_set_default_options if !@sb[:prov_options] || (@sb[:prov_options] && !@sb[:prov_options].has_key?(resource_type.to_sym))   # reset default options if requests sub tab has changed

    @current_page = @pages[:current] if @pages != nil # save the current page number
    session[:request_sortcol] = @sortcol
    session[:request_sortdir] = @sortdir

    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show
    identify_request
    return if record_no_longer_exists?(@miq_request)
    @display = params[:display] || "main" unless control_selected?

    if @display == "main"
      prov_set_show_vars
    elsif @display == "miq_provisions"
      @showtype = "miq_provisions"
      @listicon = "miq_request"
      @no_checkboxes = true
      @showlinks = true
      @view, @pages = get_view(MiqProvision, :conditions=>["miq_request_id=?", @miq_request.id])  # Get all requests
      drop_breadcrumb( {:name=>"Provisioned VMs [#{@miq_request.description}]", :url=>"/miq_request/show/#{@miq_request.id}?display=#{@display}"} )
    end
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
    @lastaction = "show"
  end

  # Stamp a request with approval or denial
  def stamp
    assert_privileges("miq_request_approval")
    if params[:button] == "cancel"
      add_flash(_("Request %s was cancelled by the user") % (session[:edit] && session[:edit][:stamp_typ]) == "a" ? "approval" : "denial")
      session[:flash_msgs] = @flash_array.dup
      @edit = nil
      render :update do |page|
        page.redirect_to :action=>@lastaction, :id=>session[:edit][:request].id
      end
    elsif params[:button] == "submit"
      return unless load_edit("stamp_edit__#{params[:id]}","show")
      stamp_request = MiqRequest.find(@edit[:request].id)         # Get the current request record
      if @edit[:stamp_typ] == "a"
        stamp_request.approve(session[:userid], @edit[:reason])
      else
        stamp_request.deny(session[:userid], @edit[:reason])
      end
#     AuditEvent.success(build_saved_audit(request, @edit))
      add_flash(_("Request \"%{name}\" was %{task}") % {:name=>stamp_request.description, :task=>(session[:edit] && session[:edit][:stamp_typ]) == "a" ? "approved" : "denied"})
      session[:flash_msgs] = @flash_array.dup                     # Put msg in session for next transaction to display
      @edit = nil
      render :update do |page|
        page.redirect_to :action=>"show_list"
      end
    else  # First time in, set up @edit hash
      identify_request
      @edit = Hash.new
      @edit[:dialog_mode] = :review
      @edit[:request] = @miq_request
      @edit[:key] = "stamp_edit__#{@miq_request.id}"
      @edit[:stamp_typ] = params[:typ]
      show
      drop_breadcrumb( {:name=>"Request #{@edit[:stamp_typ] == "a" ? "Approval" : "Denial"}", :url=>"/miq_request/stamp"} )
      render :action=>"show"
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def stamp_field_changed
    return unless load_edit("stamp_edit__#{params[:id]}","show")
    render :update do |page|                    # Use JS to update the display
      if @edit[:reason].blank?
        @edit[:reason] = params[:reason] if params[:reason]
        unless @edit[:reason].blank?
          page << "miqButtons('show');"
        end
      else
        @edit[:reason] = params[:reason] if params[:reason]
        if @edit[:reason].blank?
          page << "miqButtons('hide');"
        end
      end
    end
  end

  def prov_copy
    org_req = MiqRequest.where(:id => params[:req_id].to_i).first
    req = MiqRequest.new(
      :approval_state => 'pending_approval',
      :description    => org_req.description,
      :requester      => org_req.requester,
      :type           => org_req.type,
      :created_on     => org_req.created_on,
      :updated_on     => org_req.updated_on,
      :options        => org_req.options,
    )

    prov_set_form_vars(req)       # Set vars from existing request
    # forcing submit button to stay on for copy request, setting a key in current hash so new and current are different,
    # couldn't set this in new hash becasue that's being set by model
    @edit[:current][:description] = "Copy of #{org_req.description}"
    session[:changed] = true                                # Turn on the submit button
    drop_breadcrumb( {:name=>"Copy of VM Provision Request", :url=>"/vm/provision"} )
    @in_a_form = true
    render :action=>"prov_edit"
  end

  # To handle Continue button
  def prov_continue
    if params[:button] == "continue"                            # Continue the request from the workflow with the new options
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("prov_edit__#{id}","show_list")
      @edit[:wf].continue_request(@edit[:new], session[:userid])          # Continue the workflow with new field values based on options, need to pass userid there
      @edit[:wf].init_from_dialog(@edit[:new],session[:userid])                                 # Create a new provision workflow for this edit session
      @edit[:buttons] = @edit[:wf].get_buttons
      @edit[:wf].get_dialog_order.each do |d|                           # Go thru all dialogs, in order that they are displayed
        @edit[:wf].get_all_fields(d).keys.each do |f|                 # Go thru all field
          field = @edit[:wf].get_field(f, d)
          if !field[:error].blank?
            @error_div ||= "#{d.to_s}_div"
            add_flash(field[:error], :error)
          end
        end
      end
      #setting active tab to first visible tab
      @edit[:wf].get_dialog_order.each do |d|
        if @edit[:wf].get_dialog(d)[:display] == :show
          @edit[:new][:current_tab_key] = d
          @tabactive = "#{d.to_s}_div" # Use JS to update the display
          break
        end
      end
      render :update do |page|
        if @error_div
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        else
          page.replace("prov_wf_div", :partial=>"prov_wf")
        end
        page.replace("buttons_div", :partial=>"miq_request/prov_form_buttons")
      end
    end
  end

  def prov_load_tab
    if @options && @options[:current_tab_key] == :purpose # Need to build again for purpose tab, since it's stored in @temp
      fld = @options[:wf].kind_of?(MiqHostProvisionWorkflow) ? "tag_ids" : "vm_tags"
      build_tags_tree(@options[:wf],@options["#{fld}".to_sym],false)
    end
    #need to build host list view, to display on show screen
    @options[:host_sortdir] = "ASC"
    @options[:host_sortcol] = "name"
    #only build host grid if that field is visible/exists in dialog
    build_host_grid(@options[:wf].allowed_hosts, @options[:host_sortdir], @options[:host_sortcol]) if !@options[:wf].get_field(:src_host_ids,:service).blank? || !@options[:wf].get_field(:placement_host_name,:environment).blank?
    render :update do |page|                    # Use JS to update the display
      if @options[:wf].kind_of?(MiqProvisionWorkflow)
        page.replace_html("#{@options[:current_tab_key].to_s}_div", :partial=>"prov_dialog", :locals=>{:wf=>@options[:wf], :dialog=>@options[:current_tab_key]})
      elsif @options[:wf].class.to_s == "VmMigrateWorkflow"
        page.replace_html("#{@options[:current_tab_key].to_s}_div", :partial=>"prov_vm_migrate_dialog", :locals=>{:wf=>@options[:wf], :dialog=>@options[:current_tab_key]})
      else
        page.replace_html("#{@options[:current_tab_key].to_s}_div", :partial=>"prov_host_dialog", :locals=>{:wf=>@options[:wf], :dialog=>@options[:current_tab_key]})
      end
      # page << javascript_show("hider_#{@options[:current_tab_key].to_s}_div")
      page << "miqSparkle(false);"
    end
  end

  WORKFLOW_METHOD_WHITELIST = {'retrieve_ldap' => :retrieve_ldap}

  def retrieve_email
    @edit = session[:edit]
    begin
      method = WORKFLOW_METHOD_WHITELIST[params[:field]]
      @edit[:wf].send(method, @edit[:new]) unless method.nil?
    rescue StandardError => bang
      add_flash(_("Error retrieving LDAP info: ") << bang.message, :error)
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    else
      render :update do |page|                    # Use JS to update the display
        page.replace_html("requester_div", :partial => "prov_dialog",
                                           :locals  => {:wf => @edit[:wf], :dialog => :requester})
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  # Gather any changed options
  def prov_change_options
    resource_type = get_request_tab_type.to_sym
    @sb[:def_prov_options][resource_type][:user_choice] = params[:user_choice] if params[:user_choice]
    @sb[:def_prov_options][resource_type][:type_choice] = params[:type_choice] if params[:type_choice]
    @sb[:def_prov_options][resource_type][:time_period] = params[:time_period].to_i if params[:time_period]
    @sb[:def_prov_options][resource_type][:reason_text] = params[:reason_text] if params[:reason_text] #&& params[:reason][:text] != ""
    res_type = @sb[:prov_options][resource_type]
    res_type[:states].sort.each do |(state, display_name)|
      if params["state_choice__#{state}"] == "1"
        @sb[:def_prov_options][resource_type][:applied_states].push(state) unless @sb[:def_prov_options][resource_type][:applied_states].include?(state)
      elsif params["state_choice__#{state}"] == "null"
        @sb[:def_prov_options][resource_type][:applied_states].delete(state)
      end
    end

    applied_states_blank = @sb[:def_prov_options][resource_type][:applied_states].blank?
    add_flash(_("At least one %s must be selected") % "status", :warning) if applied_states_blank

    render :update do |page| # Do nothing to the page
      unless applied_states_blank
        # Options have changed?
        page << javascript_for_miq_button_visibility(res_type != @sb[:def_prov_options][resource_type])
      else
        # Disable buttons due to no filters being selected
        page << javascript_for_miq_button_visibility(false)
      end
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
    end
  end

  # Refresh the display with the chosen filters
  def prov_button
    @edit = session[:edit]
    if params[:button] == "apply"
      @sb[:prov_options][@sb[:prov_options][:resource_type]] = copy_hash(@sb[:def_prov_options][@sb[:prov_options][:resource_type]])  # Copy the latest changed options
    elsif params[:button] == "reset"
      @sb[:def_prov_options][@sb[:prov_options][:resource_type]] = copy_hash(@sb[:prov_options][@sb[:prov_options][:resource_type]])  # Reset to the saved options
    elsif params[:button] == "default"
      prov_set_default_options
    end
    show_list
    render :update do |page|
      page.replace("prov_options_div", :partial=>"prov_options")
      if @view.table.data.length >= 1
        page << javascript_hide("no_records_div")
        page << javascript_show("records_div")
      else
        page << javascript_show("no_records_div")
        page << javascript_hide("records_div")
      end
      page << "xml = \"#{j_str(@grid_xml)}\";"  # Set the XML data
      page << "gtl_list_grid.clearAll(true);"               # Clear grid data, including headers
      page << "gtl_list_grid.parse(xml);"                   # Reload grid from XML
      if @sortcol
        dir = @sortdir ? @sortdir[0..2] : "asc"
        page << "gtl_list_grid.setSortImgState(true, #{@sortcol + 2}, '#{dir}');"
      end
      page << "miqGridOnCheck(null, null, null);"           # Reset the center buttons
      page.replace("pc_div_1", :partial=>'/layouts/pagingcontrols', :locals=>{:pages=>@pages, :action_url=>"show_list", :db=>@view.db, :headers=>@view.headers})
      page.replace("pc_div_2", :partial=>'/layouts/pagingcontrols', :locals=>{:pages=>@pages, :action_url=>"show_list"})
    end
  end

  def post_install_callback
    MiqRequestTask.post_install_callback(params["task_id"]) if params["task_id"]
    render :nothing => true
  end

  private ############################

  def get_request_tab_type
    case @layout
    when "miq_request_vm"
      return "MiqProvisionRequest"
    when "miq_request_host"
      return "MiqHostProvisionRequest"
    when "miq_request_ae"
      return "AutomateRequest"
    end
  end

  # Create a condition from the passed in options
  def prov_condition(opts)
    cond = Array.new
    requester = User.find_by_userid(session[:userid])

    if !is_approver
      cond_hash = Hash.new
      cond_hash["="] = {"value"=> requester ? requester.id : nil,"field"=>"MiqRequest-requester_id"}
      cond.push(cond_hash)
    end

    if opts[:user_choice] && opts[:user_choice] != "all"
      cond_hash = Hash.new
      cond_hash["="] = {"value"=>opts[:user_choice],"field"=>"MiqRequest-requester_id"}
      cond.push(cond_hash)
    end

    if opts[:applied_states].present?
      opts[:applied_states].each_with_index do |state,i|
        if i == 0
          @or_hash = Hash.new
          @or_hash["or"] = Array.new
          cond_hash = Hash.new
          cond_hash["="] = {"value"=>state,"field"=>"MiqRequest-approval_state"}
          @or_hash["or"].push(cond_hash)
        elsif i == opts[:applied_states].length-1
          cond_hash = Hash.new
          cond_hash["="] = {"value"=>state,"field"=>"MiqRequest-approval_state"}
          @or_hash["or"].push(cond_hash)
          #cond.push(@or_hash)
        else
          cond_hash = Hash.new
          cond_hash["="] = {"value"=>state,"field"=>"MiqRequest-approval_state"}
          @or_hash["or"].push(cond_hash)
        end
      end
      cond.push(@or_hash)
    end

    # Add time condition
    cond_hash = Hash.new
    cond_hash["AFTER"] = {"value"=>"#{opts[:time_period].to_i} Days Ago","field"=>"MiqRequest-created_on"}
    cond.push(cond_hash)

    case @layout
    when "miq_request_ae"
      req_typ = :AutomationRequest
    when "miq_request_host"
      req_typ = :Host
    else
      req_typ = :Vm
    end
    request_types = MiqRequest::MODEL_REQUEST_TYPES[req_typ]
    request_types.each_with_index do |typ,i|
      typ.each do |k|
        if k.class == Symbol
          if i == 0
            @or_hash = Hash.new   # need this  incase there are more than one type
            @or_hash["or"] = Array.new
            cond_hash = Hash.new
            cond_hash["="] = {"value"=>k.to_s,"field"=>"MiqRequest-resource_type"}
            @or_hash["or"].push(cond_hash)
          elsif i == request_types.length-1
            cond_hash = Hash.new
            cond_hash["="] = {"value"=>k.to_s,"field"=>"MiqRequest-resource_type"}
            @or_hash["or"].push(cond_hash)
          else
            cond_hash = Hash.new
            cond_hash["="] = {"value"=>k.to_s,"field"=>"MiqRequest-resource_type"}
            @or_hash["or"].push(cond_hash)
          end
        end
      end
    end
    cond.push(@or_hash)

    if opts[:type_choice] && opts[:type_choice] != "all"  # Add request_type filter, if selected
      cond_hash = Hash.new
      cond_hash["="] = {"value"=>opts[:type_choice],"field"=>"MiqRequest-request_type"}
      cond.push(cond_hash)
    end

    if opts[:reason_text]  && opts[:reason_text] != ""
      cond_hash = Hash.new
      if opts[:reason_text].starts_with?("*") && opts[:reason_text].ends_with?("*")   # Replace beginning/ending * chars with % for SQL
        hash_key = "INCLUDES"
        reason_text = opts[:reason_text][1..-2]
      elsif opts[:reason_text].starts_with?("*")
        hash_key = "ENDS WITH"
        reason_text = opts[:reason_text][1..-1]
      elsif opts[:reason_text].ends_with?("*")
        hash_key = "STARTS WITH"
        reason_text = opts[:reason_text][0..-2]
      else
        hash_key = "INCLUDES"
        reason_text = opts[:reason_text]
      end

      cond_hash["#{hash_key}"] = {"value"=>reason_text,"field"=>"MiqRequest-reason"}
      cond.push(cond_hash)
    end

    condition = Hash.new
    condition["and"] = Array.new
    cond.each do |c|
      condition["and"].push(c)
    end
    return  MiqExpression.new(condition)
  end

  # Set all task options to default
  def prov_set_default_options
    resource_type = get_request_tab_type
    opts = @sb[:prov_options][resource_type.to_sym] = Hash.new
    opts[:states] = PROV_STATES
    opts[:reason_text] = nil
    opts[:types] = Hash.new
    case @layout
    when "miq_request_vm"
      typ = :Vm
    when "miq_request_host"
      typ = :Host
    when "miq_request_ae"
      typ = :AutomationRequest
    end
    request_types = MiqRequest::MODEL_REQUEST_TYPES[typ]
    request_types.each do |typ|
      typ.each do |k|
        if k.class == Hash
          k.each do |hsh,val|
            opts[:types][hsh] = val
          end
        end
      end
    end
    time_period = 30        # fetch uniq requesters from this time frame, since that's the highest time period in pull down.
    conditions = ["created_on>=? AND created_on<=? AND type IN (?)", time_period.days.ago.utc, Time.now.utc, request_types.keys]
    opts[:users] = MiqRequest.all_requesters(conditions)
    unless is_approver
      if opts[:users].has_value?(session[:username])
        opts[:users] = {opts[:users].key(session[:username]) => session[:username]}
      end
    end
    opts[:applied_states] = opts[:states].collect { |s| s[0] }
    opts[:type_choice] = "all"
    opts[:user_choice] ||= "all"
    opts[:time_period] ||= 7
    @sb[:def_prov_options][resource_type.to_sym] = Hash.new
    @sb[:prov_options][resource_type.to_sym] = @sb[:def_prov_options][resource_type.to_sym] = copy_hash(opts)
  end

  # Find the request that was chosen
  def identify_request
    klass = @layout == "miq_request_ae" ? AutomationRequest : MiqRequest
    return @miq_request = @record = identify_record(params[:id], klass)
  end

  def is_approver
    return %w{approver super_administrator administrator}.include?(session[:userrole])
  end

  # Delete all selected or single displayed action(s)
  def deleterequests
    assert_privileges("miq_request_delete")
    miq_requests = Array.new
    if @lastaction == "show_list" # showing a list
      miq_requests = find_checked_items
      if miq_requests.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"miq_request"), :task=>"deletion"}, :error)
      end
      process_requests(miq_requests, "destroy") unless miq_requests.empty?
      add_flash(_("The selected %s were deleted") % ui_lookup(:tables=>"miq_request")) if ! flash_errors?
    else # showing 1 request, delete it
      if params[:id] == nil || MiqRequest.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>"miq_request"), :error)
      else
        miq_requests.push(params[:id])
      end
      @single_delete = true
      process_requests(miq_requests, "destroy") if ! miq_requests.empty?
      add_flash(_("The selected %s was deleted") % ui_lookup(:table=>"miq_request")) if ! flash_errors?
    end
    show_list
    @refresh_partial = "layouts/gtl"
  end

  # Common Request button handler routines
  def process_requests(miq_requests, task)
    MiqRequest.find_all_by_id(miq_requests).each do |miq_request|
      id = miq_request.id
      request_name = miq_request.description
      if task == "destroy"
        audit = {:event=>"MiqRequest_record_delete", :message=>"[#{request_name}] Record deleted", :target_id=>id, :target_class=>"MiqRequest", :userid => session[:userid]}
      end
      begin
        miq_request.public_send(task.to_sym) if miq_request.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"MiqRequest"), :name=>request_name, :task=>task} << bang.message,
                  :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>ui_lookup(:model=>"MiqRequest"), :name=>request_name})
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model=>ui_lookup(:model=>"MiqRequest"), :name=>request_name, :task=>task})
        end
      end
    end
  end

  def get_layout
    case @request_tab
    when "vm"
      "miq_request_vm"
    when "host"
      "miq_request_host"
    when "ae"
      "miq_request_ae"
    else
      "miq_request_vm"
    end
  end

  def get_session_data
    @title        = "Requests"
    @request_tab  = session[:request_tab] if session[:request_tab]
    @layout       = get_layout
    @lastaction   = session[:request_lastaction]
    @showtype     = session[:request_lastaction]
    @display      = session[:request_display]
    @current_page = session[:request_current_page]
    @options      = session[:prov_options]
    #@edit = session[:edit] if session[:edit]
  end

  def set_session_data
    session[:edit]                 = @edit unless @edit.nil?
    session[:layout]               = @layout unless @layout.nil?
    session[:request_lastaction]   = @lastaction
    session[:request_showtype]     = @showtype
    session[:request_display]      = @display unless @display.nil?
    session[:request_tab]          = @request_tab unless @request_tab.nil?
    session[:request_current_page] = @current_page
    session[:prov_options]         = @options if @options
  end

end
