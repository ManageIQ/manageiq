module ApplicationController::Automate
  extend ActiveSupport::Concern

  def resolve_button_throw
    if valid_resolve_object?
      add_flash(_("Automation Simulation has been run"))
      @sb[:name] = @resolve[:new][:instance_name].blank? ? @resolve[:new][:other_name] : @resolve[:new][:instance_name]
      @sb[:attrs] = {}
      @resolve[:new][:attrs].each do |a|
        @sb[:attrs][a[0].to_sym] = a[1] unless a[0].blank?
      end
      @sb[:obj] = if @resolve[:new][:target_id] && @resolve[:new][:target_class]
                    @resolve[:new][:target_class].constantize.find(@resolve[:new][:target_id])
                  end
      @resolve[:button_class] = @resolve[:new][:target_class]
      @resolve[:button_number] ||= 1
      @sb[:attrs][:request] = @resolve[:new][:object_request] # Add the request attribute value entered by the user
      begin
        build_results
      rescue MiqAeException::Error => bang
        add_flash(_("Automation Error: %{error_message}") % {:error_message => bang.message}, :error)
      end
    end
    c_tb = build_toolbar(center_toolbar_filename)
    render :update do |page|
      # IE7 doesn't redraw the tree until the screen is clicked, so redirect back to this method for a refresh
      if is_browser_ie? && browser_info(:version) == "7"
        page.redirect_to :action => 'resolve'
      else
        page.replace("left_cell_bottom", :partial => "resolve_form_buttons")
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace_html("main_div", :partial => "results_tabs")
        page << javascript_pf_toolbar_reload('center_tb', c_tb)
        page << "miqSparkle(false);"
      end
    end
  end
  private :resolve_button_throw

  def resolve_button_copy # Copy current URI as an automate button
    session[:resolve_object] = copy_hash(@resolve)
    head :ok
  end
  private :resolve_button_copy

  def resolve_button_paste # Copy current URI as an automate button
    @resolve = copy_hash(session[:resolve_object])
    @edit = session[:edit]
    @custom_button = @edit[:custom_button]
    @edit[:instance_names]       = @resolve[:instance_names]
    @edit[:new][:instance_name]  = @resolve[:new][:instance_name]
    @edit[:new][:object_message] = @resolve[:new][:object_message]
    @edit[:new][:object_request] = @resolve[:new][:object_request]
    @edit[:new][:attrs]          = @resolve[:new][:attrs]
    @edit[:new][:target_class]   = @resolve[:target_class] = Hash[*@resolve[:target_classes].flatten.reverse][@resolve[:new][:target_class]]
    @edit[:uri] = @resolve[:uri]
    (AE_MAX_RESOLUTION_FIELDS - @resolve[:new][:attrs].length).times { @edit[:new][:attrs].push([]) }
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page.replace_html("main_div", :partial => "shared/buttons/ab_list")
      page << javascript_for_miq_button_visibility_changed(@changed)
      page << "miqSparkle(false);"
    end
  end
  private :resolve_button_paste

  def resolve_button_simulate # Copy current URI as an automate button
    @edit = copy_hash(session[:resolve])
    @resolve[:new][:attrs] = []
    if @edit[:new][:attrs]
      attrs = copy_array(@edit[:new][:attrs]) # using copy_array, otherwise on simulation screen it was updating @edit attrs as well while updating attrs for resolve
      attrs.each do |attr|
        @resolve[:new][:attrs].push(attr) unless @resolve[:new][:attrs].include?(attr)
      end
    end
    (AE_MAX_RESOLUTION_FIELDS - @resolve[:new][:attrs].length).times { @resolve[:new][:attrs].push([]) }
    if @edit[:new][:instance_name] && @edit[:instance_names].include?(@edit[:new][:instance_name])
      @resolve[:new][:instance_name] = @edit[:new][:instance_name]
    else
      @resolve[:new][:instance_name] = nil
      @resolve[:new][:other_name] = @edit[:new][:other_name]
    end
    if @edit[:new][:target_class]
      @resolve[:new][:target_class] = Hash[*@resolve[:target_classes].flatten][@edit[:new][:target_class]]
      target_class = @resolve[:target_classes].detect { |ui_name, _| @edit[:new][:target_class] == ui_name }.first
      targets = target_class.constantize.all
      @resolve[:targets] = targets.sort_by { |t| t.name.downcase }.collect { |t| [t.name, t.id.to_s] }
      @resolve[:new][:target_id] = nil
      @resolve[:new][:object_message] = @edit[:new][:object_message]
      @resolve[:lastaction] = "simulate"
      @resolve[:throw_ready] = ready_to_throw
    end

    # workaround to get "Simulate button" work from customization explorer
    render :update do |page|
      page.redirect_to :action => 'resolve', :controller => "miq_ae_tools", :simulate => "simulate", :escape => false
    end
  end
  private :resolve_button_simulate

  def resolve_button_reset_or_none # Reset or first time in
    @accords = [{:name => "resolve", :title => "Options", :container => "resolve_form_div"}]

    if params[:simulate] == "simulate"
      @resolve = session[:resolve]
      @resolve[:ae_result] = nil
    else
      @resolve = {} if params[:button] == "reset" || (@resolve && @resolve[:lastaction] == "simulate")
      @resolve[:lastaction] = nil if @resolve
      build_resolve_screen
    end

    @sb[:active_tab] = "tree"
    if params[:button] == "reset"
      add_flash(_("All changes have been reset"), :warning)
      resolve_reset
    else
      render :layout => "application"
    end
  end
  private :resolve_button_reset_or_none

  def resolve
    custom_button_redirect = params[:button] == 'simulate' || params[:simulate] == 'simulate'
    assert_privileges(custom_button_redirect ? 'ab_button_simulate' : 'miq_ae_class_simulation')
    @explorer = true
    @collapse_c_cell = true
    @breadcrumbs = []
    drop_breadcrumb(:name => "Resolve", :url => "/miq_ae_tools/resolve")
    @lastaction = "resolve"
    @right_cell_text = "Simulation"

    case params[:button]
    when "throw", "retry" then resolve_button_throw
    when "copy"     then resolve_button_copy
    when "paste"    then resolve_button_paste
    when "simulate" then resolve_button_simulate
    else                 resolve_button_reset_or_none
    end
  end

  def build_results
    options = {
      :vmdb_object => @sb[:obj],
      :fqclass     => @resolve[:new][:starting_object],
      :message     => @resolve[:new][:object_message]
    }
    @resolve[:state_attributes] = {} if params[:button] == 'throw'
    automation_attrs = @sb[:attrs].reverse_merge(@resolve[:state_attributes])
    ws = MiqAeEngine.resolve_automation_object(@sb[:name],
                                               User.current_user,
                                               automation_attrs,
                                               options,
                                               @resolve[:new][:readonly])
    ws.root['ae_result'] ||= 'ok'
    @results = ws.to_expanded_xml
    @resolve[:uri] = options[:uri]
    @resolve[:ae_result] = ws.root['ae_result']
    @resolve[:state_attributes] = ws.root['ae_result'] == 'retry' ? state_attributes(ws) : {}
    @json_tree = ws_tree_from_xml(@results)
  end

  def state_attributes(ws)
    state_attrs = {'ae_state_retries' => ws.root['ae_state_retries'],
                   'ae_state'         => ws.root['ae_state']}
    state_attrs['ae_state_data'] = ws.persist_state_hash.to_yaml unless ws.persist_state_hash.empty?
    state_attrs['ae_state_previous'] = ws.current_state_info.to_yaml unless ws.current_state_info.empty?
    state_attrs
  end

  def ready_to_throw
    @resolve[:new][:target_class].blank? || !@resolve[:new][:target_id].blank?
  end

  def resolve_reset
    c_tb = build_toolbar(center_toolbar_filename)
    render :update do |page|
      page.replace("left_cell_bottom", :partial => "resolve_form_buttons")
      page.replace("resolve_form_div", :partial => "resolve_form") unless params[:tab_id]
      page.replace("results_tabs",     :partial => "results_tabs")
      page << javascript_pf_toolbar_reload('center_tb', c_tb)
      page << "miqSparkle(false);"
    end
  end
end
