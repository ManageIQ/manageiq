module ApplicationController::DialogRunner
  extend ActiveSupport::Concern

  def dialog_form_button_pressed
    case params[:button]
      when "cancel"
        flash = _("%s was cancelled by the user") % "#{ui_lookup(:model=>'Service')} Order"
        @sb[:action] = @edit = nil
        @in_a_form = false
        if session[:edit][:explorer]
          add_flash(flash)
          replace_right_cell
        else
          render :update do |page|
            page.redirect_to :action => 'show', :id => session[:edit][:target_id],
                             :flash_msg => flash  # redirect to miq_request show_list screen
          end
        end
      when "submit"
        return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
        begin
          result = @edit[:wf].submit_request(session[:userid])
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") %  "Provisioning" << bang.message, :error)
          render :update do |page|                    # Use RJS to update the display
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        else
          unless result[:errors].blank?
            #show validation errors
            result[:errors].each do |err|
              add_flash(err, :error)
            end
            render :update do |page|                    # Use JS to update the display
              page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
            end
          else
            flash = _("%s Request was Submitted") % "Order"
            @sb[:action] = @edit = nil
            @in_a_form = false
            if session[:edit][:explorer]
              add_flash(flash)
              if request.parameters[:controller] == "catalog"
                #only do this Service PRovision requests
                render :update do |page|
                  page.redirect_to :controller=>'miq_request', :action => 'show_list', :flash_msg=>flash  # redirect to miq_request show_list screen
                end
              else
                replace_right_cell
              end
            else
              render :update do |page|
                page.redirect_to :action => 'show', :id => session[:edit][:target_id],
                                 :flash_msg => flash  # redirect to miq_request show_list screen
              end
            end
          end
        end
      when "reset"  # Reset
        dialog_reset_form
        flash = _("All changes have been reset")
        if session[:edit][:explorer]
          add_flash(flash, :warning)
          replace_right_cell("dialog_provision")
        else
          render :update do |page|
            page.redirect_to :action => 'dialog_load', :flash_msg => flash, :flash_warning => true, :escape => false  # redirect to miq_request show_list screen
          end
        end
      else
        return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
        add_flash(_("%s Button not yet implemented") % "#{params[:button].capitalize}", :error)
        render :update do |page|                    # Use RJS to update the display
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def dialog_field_changed
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    dialog_get_form_vars

    # Use JS to update the display
    render :update do |page|
#     page.replace_html("main_div", :partial=>"st_form") if params[:resource_id] || @group_idx || params[:display]
#      if changed
#       #sample commands to change values of fields when showing hidden tr's
#       page << "$('check_box_1').checked = true"
#       page << "$('text_area_box_1').value = 'text'"
#       page << "$('f2').options[0]= new Option('value 1', 'val1');"
#       page << "$('f2').options[1]= new Option('value 2', 'val2');"
#       page << "$('f2').value = 'val2'"
#       page << javascript_for_miq_button_visibility(changed)
        @edit[:wf].dialog.dialog_tabs.each do |tab|
          tab.dialog_groups.each do |group|
            group.dialog_fields.each_with_index do |field,i|
              params.each do |p|
                if p[0] == field.name

                  url = url_for(:action => 'dialog_field_changed', :id=>"#{@edit[:rec_id] || "new"}")

                  if field.type.include?("Radio")
                    # No need to replace radio buttons, browser takes care of select/deselect

                  elsif field.type.include?("DropDown") && field.required
                     url = url_for(:action => 'dialog_field_changed', :id=>"#{@edit[:rec_id] || "new"}")
                     page.replace("#{field.name}", :text => "#{select_tag(field.name, options_for_select(field.values.collect{|v| v.reverse}, p[1]), 'data-miq_sparkle_on' => true, 'data-miq_sparkle_off'=> true, 'data-miq_observe'=>{:url=>url}.to_json)}")

                  elsif field.type.include?("TagControl") && field.single_value? && field.required
                    category_tags = DialogFieldTagControl.category_tags(field.category).map {|cat| [cat[:description], cat[:id]]}
                    page.replace("#{field.name}", :text => "#{select_tag(field.name, options_for_select(category_tags, p[1]), 'data-miq_sparkle_on' => true, 'data-miq_sparkle_off'=> true, 'data-miq_observe'=>{:url=>url}.to_json)}")
                  end
                end
              end
            end
          end
        end
#     end
      page << "miqSparkle(false);"
    end
  end

  #for non-explorer screen
  def dialog_load
    @edit = session[:edit]
    @record = Dialog.find_by_id(@edit[:rec_id])
    @dialog_prov = true
    @in_a_form = true
    @showtype = "dialog_provision"
    render :action => "show"
  end

  def dynamic_list_refresh
    # FIXME: customer defined field names can clash with elements in the page!
    # this problem applies not only to the action here, but also to all of the
    # app/views/shared/dialogs/_dialog_field.html.erb and more...

    @edit = session[:edit]
    dialog_id = @edit[:rec_id]
    url = url_for(:action => 'dialog_field_changed', :id => dialog_id)

    dialog = @edit[:wf].dialog
    field  = dialog.field(params[:id])

    field.refresh_button_pressed

    render :update do |page|
      page.replace(params[:id],
        select_tag(field.name, options_for_select(field.values, @edit[:wf].value(field.name)),
                   'data-miq_sparkle_on'  => true,
                   'data-miq_sparkle_off' => true,
                   'data-miq_observe'     => { :url => url }.to_json))
    end
  end

  private     #######################

  def dialog_reset_form
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    @edit[:new] = copy_hash(@edit[:current])
    @record = Dialog.find_by_id(@edit[:rec_id])
    @right_cell_text = @edit[:right_cell_text]
    @in_a_form = true
  end

  def build_sample_tree
    parent_node = Hash.new                        # Build the ci node
    parent_node['id'] = "Tags"
    parent_node['text'] = "Tags"
    parent_node['tooltip'] = "Tags"
    parent_node['style'] = "cursor:default;font-weight:bold;" # Show node as different
    parent_node['nocheckbox'] = true
    parent_node['radio'] = "1"
    child_node = Array.new
    temp = Hash.new
    temp['id'] = "tag_1"
    temp['tooltip'] = "Tag 1"
    temp['style'] = "cursor:default"
    temp['text'] = "Tag 1"
    temp['im0'] = temp['im1'] = temp['im2'] = "tag.png"
    child_node.push(temp)
    parent_node['item'] = child_node
    @temp[:sample_tree] = {"id"=>0, "item"=>[parent_node]}.to_json
  end

  def dialog_initialize(ra, options)
    @edit = Hash.new
    @edit[:new] = options[:dialog] || {}
    opts = {
      :target => options[:target_kls].constantize.find_by_id(options[:target_id])
    }
    @edit[:wf] = ResourceActionWorkflow.new(@edit[:new],session[:userid],ra,opts)
    @record = Dialog.find_by_id(ra.dialog_id.to_i)
    @edit[:rec_id]   = @record.id
    @edit[:key]     = "dialog_edit__#{@edit[:rec_id] || "new"}"
    @edit[:explorer] = @explorer ? @explorer : false
    @edit[:target_id] = options[:target_id]
    @edit[:target_kls] = options[:target_kls]
    @edit[:dialog_mode] = options[:dialog_mode]
    @edit[:current] = copy_hash(@edit[:new])
    @edit[:right_cell_text] = options[:header].to_s
    build_sample_tree
    @in_a_form = true
    @changed = session[:changed] = true
    if @edit[:explorer]
      replace_right_cell("dialog_provision")
    else
      render :update do |page|
        page.redirect_to :action => 'dialog_load'
      end
    end
  end

  def dialog_get_form_vars
    @record = Dialog.find_by_id(@edit[:rec_id])

    params.each do |p|

      #if p[0] contains name w/ __protected(password field), so remove it
      p[0] = p[0].split("__protected").first if p[0].ends_with?("__protected")

      #if date/datetime field came in
      if p[0].starts_with?("miq_date__")

        @edit[:wf].set_value(p[0].split("miq_date__").last,p[1]) if @record.field_name_exist?(p[0].split("miq_date__").last)

      #if start hour/min came in for date/datetime field
      elsif ["start_hour", "start_min"].include?(p[0])
        field_name = ""

        @edit[:wf].dialog.dialog_tabs.each do |tab|
          tab.dialog_groups.each do |group|
            group.dialog_fields.each_with_index do |field,i|
              field_name = field.name if ["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(field.type)
            end
          end
        end

        #if user didnt choose the date and goes with default shown in the textbox, need to set that value in wf before adding hour/min
        if @edit[:wf].value(field_name).nil?
          t = Time.now.in_time_zone(session[:user_tz]) + 1.day
          date_val = ["#{t.month}/#{t.day}/#{t.year}"]
          @edit[:wf].set_value(field_name,date_val)
        else
          date_val = @edit[:wf].value(field_name).split(" ")
        end

        start_hour = date_val.length >= 2 ? date_val[1].split(":").first : 0
        start_min = date_val.length >= 3 ? date_val[1].split(":").last : 0

        if p[0] == "start_hour"
          @edit[:wf].set_value(field_name,"#{date_val[0]} #{p[1]}:#{start_min}")
        else
          @edit[:wf].set_value(field_name,"#{date_val[0]} #{start_hour}:#{p[1]}")
        end

      elsif @edit[:wf].dialog.field(p[0]).try(:type) == "DialogFieldCheckBox"
        checkbox_value = p[1] == "1" ? "t" : "f"
        @edit[:wf].set_value(p[0], checkbox_value) if @record.field_name_exist?(p[0])

      else
        @edit[:wf].set_value(p[0],p[1]) if @record.field_name_exist?(p[0])
      end
    end

  end
end
