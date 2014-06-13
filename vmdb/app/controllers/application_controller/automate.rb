module ApplicationController::Automate
  extend ActiveSupport::Concern

  # Perform AE resolution
  #Moving it here, this method is called when "Paste" button is pressed in customization explorer
  def resolve
    assert_privileges("ab_button_simulate")
    @explorer = true
    @collapse_c_cell = true
    @breadcrumbs = Array.new
    drop_breadcrumb( {:name=>"Resolve", :url=>"/miq_ae_tools/resolve"} )
    @lastaction = "resolve"
    if params[:button] == "throw"
      if valid_resolve_object?
        add_flash(I18n.t("flash.automate.simulation_started"))
        @sb[:name] = @resolve[:new][:instance_name].blank? ? @resolve[:new][:other_name] : @resolve[:new][:instance_name]
        @sb[:attrs] = Hash.new
        @resolve[:new][:attrs].each do |a|
          @sb[:attrs][a[0].to_sym] = a[1] unless a[0].blank?
        end
#       attrs[@resolve[:new][:target_attr_name]] = @resolve[:new][:target_class].constantize.find(@resolve[:new][:target_id]) unless @resolve[:new][:target_attr_name].blank?
        @sb[:obj] = @resolve[:new][:target_class].constantize.find(@resolve[:new][:target_id]) unless @resolve[:new][:target_id].blank?
#       @resolve[:button_attr_name] = @resolve[:new][:target_attr_name]
        @resolve[:button_class] = @resolve[:new][:target_class]
        @resolve[:button_number] ||= 1
        @sb[:attrs][:request] = @resolve[:new][:object_request] # Add the request attribute value entered by the user
        begin
          build_results
        rescue MiqAeException::Error => bang
          add_flash(I18n.t("flash.automate.automate_error") << bang.message, :error)
        end
      end
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
      render :update do |page|                    # Use JS to update the display
        # IE7 doesn't redraw the tree until the screen is clicked, so redirect back to this method for a refresh
        if is_browser_ie? && browser_info("version") == "7"
          page.redirect_to :action => 'resolve'
        else
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          page.replace_html("main_div", :partial=>"results_tabs")
          if c_buttons && c_xml
            page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
            page << "$('center_buttons_div').show();"
          else
            page << "$('center_buttons_div').hide();"
          end
          page << "miqSparkle(false);"
        end
      end
    elsif params[:button] == "save"         # Save current URI as an automate button
      # need to strip and pass description as nil, incase button is being deleted
      @resolve[:button_text] = @resolve[:button_text].strip == "" ? nil : @resolve[:button_text] if !@resolve[:button_text].nil?
      begin
        CustomButton.save_as_button(:description=>@resolve[:button_text],
                                    :applies_to_class=>@resolve[:button_class],
                                    :uri=>@resolve[:uri],
                                    :userid=>session[:userid]
#                                   :target_attr_name=>@resolve[:button_attr_name]
                                    )
      rescue StandardError => bang
        add_flash(I18n.t("flash.error_during", :task=>"save") << bang.message, :error)
      else
        if @resolve[:button_text].blank?
          add_flash(I18n.t("flash.automate.button_cleared", :btn_num=>@resolve[:button_number]))
        else
          add_flash(I18n.t("flash.automate.button_set", :btn_num=>@resolve[:button_number], :btn_txt=>@resolve[:button_text]))
        end
      end
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    elsif params[:button] == "copy"         # Copy current URI as an automate button
      session[:resolve_object] = copy_hash(@resolve)
      render :nothing => true
    elsif params[:button] == "paste"          # Copy current URI as an automate button
      @resolve = copy_hash(session[:resolve_object])
      @edit = session[:edit]
      @custom_button = @edit[:custom_button]
      @edit[:instance_names] = @resolve[:instance_names]
      @edit[:new][:instance_name] = @resolve[:new][:instance_name]
      @edit[:new][:object_message] = @resolve[:new][:object_message]
      @edit[:new][:object_request] = @resolve[:new][:object_request]
      @edit[:new][:attrs] = @resolve[:new][:attrs]
      #@edit[:new][:target_class] = @resolve[:target_class] = @resolve[:new][:target_class]
      @edit[:new][:target_class] = @resolve[:target_class] = Hash[*@resolve[:target_classes].flatten.reverse][@resolve[:new][:target_class]]
#     @edit[:new][:target_attr_name] = @resolve[:new][:target_attr_name]
      @edit[:uri] = @resolve[:uri]
      (AE_MAX_RESOLUTION_FIELDS - @resolve[:new][:attrs].length).times{@edit[:new][:attrs].push(Array.new)}
      @changed = (@edit[:new] != @edit[:current])
      render :update do |page|                    # Use JS to update the display
        page.replace_html("main_div", :partial=>"shared/buttons/ab_list")
        page << javascript_for_miq_button_visibility_changed(@changed)
        page << "miqSparkle(false);"
      end
    elsif params[:button] == "simulate"         # Copy current URI as an automate button
      @edit = copy_hash(session[:resolve])
      @resolve[:new][:attrs] = Array.new
      if @edit[:new][:attrs]
        attrs = copy_array(@edit[:new][:attrs])   #using copy_array, otherwise on simulation screen it was updating @edit arttrs as well while updating attrs for resolve
        attrs.each do |attr|
          @resolve[:new][:attrs].push(attr) unless @resolve[:new][:attrs].include?(attr)
        end
      end
      (AE_MAX_RESOLUTION_FIELDS - @resolve[:new][:attrs].length).times{@resolve[:new][:attrs].push(Array.new)}
      if @edit[:new][:instance_name] && @edit[:instance_names].include?(@edit[:new][:instance_name])
        @resolve[:new][:instance_name] = @edit[:new][:instance_name]
      else
        @resolve[:new][:instance_name] = nil
        @resolve[:new][:other_name] = @edit[:new][:other_name]
      end
      @resolve[:new][:target_class] = Hash[*@resolve[:target_classes].flatten][@edit[:new][:target_class]]
#     @resolve[:new][:target_attr_name] = @edit[:new][:target_attr_name]
      target_class = @resolve[:target_classes].detect {|ui_name, model_name| @edit[:new][:target_class] == ui_name}.last
      targets = target_class.constantize.all
      @resolve[:targets] = targets.sort{|a,b|a.name.downcase<=>b.name.downcase}.collect{|t|[t.name, t.id.to_s]}
      @resolve[:new][:target_id] = nil
      @resolve[:new][:object_message] = @edit[:new][:object_message]
      @resolve[:lastaction] = "simulate"
      @resolve[:throw_ready] = ready_to_throw
      #workaround to get "Simulate button" work from customization explorer
      render :update do |page|
        page.redirect_to :action => 'resolve', :controller=>"miq_ae_tools", :simulate => "simulate", :escape => false
      end
    else  # Reset or first time in
      @accords = [{:name=>"resolve", :title=>"Options", :container=>"resolve_form_div"}]
      if params[:simulate] == "simulate"
        @resolve = session[:resolve]
      else
        @resolve = Hash.new if params[:button] == "reset" || (@resolve && @resolve[:lastaction] == "simulate")
        @resolve[:lastaction] = nil if @resolve
        build_resolve_screen
      end
      @sb[:active_tab] = "tree"
      if params[:button] == "reset"
        add_flash(I18n.t("flash.edit.reset"), :warning)
        resolve_reset
      else
        render :layout => "explorer"
      end
    end
  end

  def build_results
    @resolve[:uri] = MiqAeEngine.create_automation_object(@sb[:name], @sb[:attrs], :vmdb_object => @sb[:obj], :fqclass => @resolve[:new][:starting_object], :message => @resolve[:new][:object_message])
    @temp[:results] = MiqAeEngine.resolve_automation_object(@resolve[:uri], :ws, @resolve[:new][:readonly]).to_expanded_xml
    @temp[:json_tree] = ws_tree_from_xml(@temp[:results])
  end

  def ready_to_throw
# Replaced following in Sprint 63, not allowing :other_name, for now
#   return (!@resolve[:new][:instance_name].blank? || !@resolve[:new][:other_name].blank?) &&
#           (@resolve[:new][:target_attr_name].blank? ||
#             (!@resolve[:new][:target_class].blank? && !@resolve[:new][:target_id].blank?)
#           )
    return  @resolve[:new][:target_class].blank? || !@resolve[:new][:target_id].blank?
  end

  def resolve_reset
    c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    render :update do |page|                    # Use JS to update the display
      page.replace("resolve_form_div", :partial=>"resolve_form") unless params[:tab_id]
      page.replace("results_tabs", :partial=>"results_tabs")
      if c_buttons && c_xml
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << "$('center_buttons_div').show();"
      else
        page << "$('center_buttons_div').hide();"
      end
      page << "miqSparkle(false);"
    end
  end
end
