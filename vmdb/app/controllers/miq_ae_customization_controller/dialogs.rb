module MiqAeCustomizationController::Dialogs
  extend ActiveSupport::Concern

  def dialog_sort_values
    if @edit[:field_data_typ] == "integer"
      val = @edit[:field_values].sort_by {|d| @edit[:field_sort_by] == "value" ? d.first.to_i : d.last.to_i}
      val = val.reverse if @edit[:field_sort_order] == "descending"
    else
      val = @edit[:field_values].sort_by {|d| @edit[:field_sort_by] == "value" ? d.first : d.last}
      val = val.reverse if @edit[:field_sort_order] == "descending"
    end

    @edit[:field_values] = copy_array(val)
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def dialog_form_field_changed
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    @record = @edit[:dialog]
    dialog_get_form_vars

    #dialog_edit_set_form_vars
    dialog_edit_build_tree
    dialog_sort_values if (params[:field_data_typ] || params[:field_sort_by] ||
        params[:field_sort_order]) && @edit[:field_sort_by].to_s != "none"
    @_params[:typ] = ""
    get_field_types

    # Use JS to update the display
    render :update do |page|
      if @flash_array
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      else
        page.replace_html(@refresh_div, :partial=>@refresh_partial, :locals=>{ :entry=>nil}) if @refresh_div
        changed = (@edit[:new] != @edit[:current])
        page.replace_html("dialog_edit_tree_div", :partial => "dialog_edit_tree")
        page << javascript_for_miq_button_visibility(changed)

        if params[:field_past_dates]
          if params[:field_past_dates] == "1"
            page << "miq_cal_dateFrom = undefined ;"
          else
            date_tz = Time.now.in_time_zone(session[:user_tz]).strftime("%Y,%m,%d")
            page << "miq_cal_dateFrom = new Date('#{date_tz}');"
          end
        end

        #url to be used in url in miqDropComplete method
        page << "miq_widget_dd_url = 'miq_ae_customization/dialog_res_reorder'"

        #refresh fields div incase select type was DialogFieldDropDownList/DialogFieldRadionButton or
        page.replace("dialog_field_div", :partial=>"dialog_field_form") if params[:field_typ] ||
            params[:field_sort_by] || params[:field_protected] || params[:field_category] ||
            params[:field_show_refresh_button] || params[:field_validator_type] || params[:field_dynamic]

        unless @edit[:field_typ] && @edit[:field_typ].include?("TagControl")
          page.replace("field_values_div", :partial=>"field_values", :locals=>{ :entry=>nil}) if params[:field_data_typ] ||
            params[:field_sort_by] || params[:field_sort_order] || params[:field_dynamic]
        end
        page << "miqInitDashboardCols();"
      end
      page << "miqSparkle(false);"
    end

  end

  def dialog_delete
    assert_privileges("dialog_delete")
    dialog_button_operation('destroy', 'Delete')
  end

  def dialog_list
    @lastaction = "dialog_list"
    #@force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    @explorer            = true

    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end

    @sortcol = session[:dialog_sortcol].nil? ? 0 : session[:dialog_sortcol].to_i
    @sortdir = session[:dialog_sortdir].nil? ? "ASC" : session[:dialog_sortdir]

    # Get the records (into a view) and the paginator
    @view, @pages = get_view(Dialog)

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:dialog_sortcol] = @sortcol
    session[:dialog_sortdir] = @sortdir

    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      # Use RJS to update the display
      render :update do |page|
        page.replace("gtl_div",
                     :partial => "layouts/x_gtl",
                     :locals  => {:action_url => "dialog_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
        page << "miqSparkle(false)"
      end
    end

  end

  #Add new dialog
  def dialog_new
    assert_privileges("dialog_new")
    @record = Dialog.new
    dialog_set_form_vars
    @in_a_form = true
    @sb[:node_typ] = nil
    replace_right_cell(x_node)
  end

  #Add new dialog
  def dialog_copy
    assert_privileges("dialog_copy")
    unless params[:id]
      obj = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end

    @record = identify_record(params[:id], Dialog) if params[:id]
    dialog_set_form_vars
    @edit[:new][:label] = "Copy of #{@record.label}"
    @edit[:dialog] = @record = Dialog.new
    @edit[:rec_id] = @record.id ? @record.id : nil
    @edit[:key] = "dialog_edit__#{@record.id || "new"}"
    session[:changed] = @in_a_form = true
    @sb[:node_typ] = nil
    replace_right_cell(x_node)
  end

  def change_tab
    get_node_info
    replace_right_cell(x_node)
  end

  #add resource to a dialog
  def dialog_res_add
    id = params[:id].strip == "" ? "new" : params[:id]
    return unless load_edit("dialog_edit__#{id}","replace_cell__explorer")
    @record = @edit[:dialog]
    @in_a_form = true
    valid = dialog_validate

    if valid
      @sb[:node_typ] = params[:typ]
      @sb[:edit_typ] = "add"
      #dialog_edit_build_tree(:dialog_edit,:dialog_edit_tree)
      nodes = x_node.split('_')

      case params[:typ]
      when "tab"
        @edit[:new][:tabs] ||= []
        @edit[:new][:tabs].push({:label=>nil,:description=>nil})
        @edit[:tab_label] = @edit[:tab_description] = nil
        @sb[:node_typ] = "tab"

      when "box"
        @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups] ||= []
        key = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups]
        key ||= []
        key.push({:label=>nil,:description=>nil})
        @edit[:group_label] = @edit[:group_description] = nil
        @sb[:node_typ] = "box"

      when "element"
        get_field_types
        @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields] ||= []
        key = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
        key.push({:label=>nil,:description=>nil,:typ=>"DialogFieldButton"})
        @edit[:field_label] = @edit[:field_name] = @edit[:field_description] =
            @edit[:field_required] = @edit[:field_typ] = @edit[:field_values] =
            @edit[:field_default_value] = @edit[:field_sort_by] = @edit[:field_sort_order] = @edit[:field_data_typ] = nil
        @sb[:node_typ] = "element"
      end

      replace_right_cell(x_node, [:dialog_edit])

    else
      render_flash do |page|
        page << "miqSparkle(false);"
      end
    end
  end

  # edit dialog
  def dialog_edit
    assert_privileges("dialog_edit")
    case params[:button]
    when 'cancel'
      @edit = session[:edit] = nil # clean out the saved info
      self.x_active_tree = :dialogs_tree
      if !@record || @record.id.blank?
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"Dialog"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"Dialog"), :name=>@record.label})
      end
      get_node_info
      replace_right_cell(x_node)

    when 'add', 'save'
      id = params[:id] || 'new'
      return unless load_edit("dialog_edit__#{id}","replace_cell__explorer")
      @record = @edit[:dialog]

      # Get new or existing record
      dialog = @record.id.blank? ? Dialog.new : Dialog.find_by_id(@record.id)
      valid = dialog_validate

      if @flash_array
        render_flash
        return
      end

      begin
        dialog_set_record_vars(dialog)
      rescue StandardError => @bang
        add_flash(@bang.message, :error)
        @changed = true
        render_flash
      else
        if params[:button] == "add"
          add_flash(_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"MiqDialog"), :name=>dialog.label})
        else
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"MiqDialog"), :name=>dialog.label})
        end

        AuditEvent.success(build_saved_audit(dialog, @edit))
        @edit = session[:edit] = nil  # clean out the saved info
        @in_a_form = session[:changed] = false
        self.x_active_tree = :dialogs_tree

        if params[:button] == "add"
          d = Dialog.find_by_label(dialog.label)
          self.x_node = "dg-#{to_cid(d.id)}"
        end

        get_node_info
        replace_right_cell(x_node,[:dialogs])
      end

    when 'reset', nil      # first time in or resettting
      unless params[:id]
        obj = find_checked_items
        @_params[:id] = obj[0] unless obj.empty?
      end

      @record = identify_record(params[:id], Dialog) if params[:id]
      session[:changed] = false
      dialog_set_form_vars
      @sb[:node_typ] = nil
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      @in_a_form = true
      replace_right_cell(x_node)
    end

  end

  # AJAX driven routine to discard new added resource that is not saved yet
  def dialog_res_discard
    assert_privileges("dialog_res_discard")
    id = params[:id].strip == "" ? "new" : params[:id]
    return unless load_edit("dialog_edit__#{id}","replace_cell__explorer")
    @record = @edit[:dialog]
    @in_a_form = true

    nodes = x_node.split('_')
    case nodes.length
    when 2
      if @sb[:edit_typ] == "add"
        @sb[:node_typ] = nil
        @edit[:new][:tabs].pop
        @edit[:new].delete(:tab_name)
        @edit[:new].delete(:tab_description)
        self.x_node = nodes[0]
      end
    when 3
      if @sb[:edit_typ] == "add"
        @sb[:node_typ] = "tab"
        @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups].pop
        @edit[:new].delete(:group_name)
        @edit[:new].delete(:group_description)
        self.x_node = "#{nodes[0]}_#{nodes[1]}"
      end
    else
      if nodes.length == 4 || nodes.length != 1 && @sb[:edit_typ] == "add"
        @sb[:node_typ] = "box"
        @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields].pop
        @edit[:new].delete(:field_name)
        @edit[:new].delete(:field_description)
        self.x_node = "#{nodes[0]}_#{nodes[1]}_#{nodes[2]}"
      end
    end
    dialog_edit_build_tree
    @sb[:edit_typ] = nil
    replace_right_cell(x_node, [:dialog_edit])
  end

  def dialog_resource_remove
    assert_privileges("dialog_resource_remove")
    #need to set widget_id using curr_pos and id of the element in @edit[:new]
    nodes = x_node.split('_')
    selected_node = nodes.last.split('-')
    @_params[:widget_id] = "#{selected_node.last}_#{selected_node.first}"
    case nodes.length
    when 2
      @_params[:typ] = "tab"
    when 3
      @_params[:typ] = "box"
    when 4
      @_params[:typ] = "element"
    end
    dialog_res_remove
  end

  #remove a resource from dialog
  def dialog_res_remove
    id = params[:id].strip == "" ? "new" : params[:id]
    return unless load_edit("dialog_edit__#{id}","replace_cell__explorer")
    @record = @edit[:dialog]
    nodes = x_node.split('_')
    if nodes.length == 1 || params[:typ] == "tab"     #Remove tab was pressed
      #need to delete tab and it's groups/fields
      idx = nil
      @edit[:new][:tabs].each_with_index do |tab,i|
        idx = i if tab[:id] == params[:widget_id].split('_').last.to_i
      end
      #if object hasn't been added to db yet, use current position to delete the selected widget
      idx = params[:widget_id].split('_').first.to_i if idx.nil?
      #saving in sandbox before deleting, to be used if discard button is pressed
      @sb[:tabs] = copy_array(@edit[:new][:tabs])
      @edit[:new][:tabs].delete_at(idx) if idx
    elsif nodes.length == 2 || params[:typ] == "box"    #Remove group was pressed
      #need to delete group and it's fields
      idx = nil
      groups = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups]
      groups.each_with_index do |group,i|
        idx = i if group[:id] == params[:widget_id].split('_').last.to_i
      end
      #if object hasn't been added to db yet, use current position to delete the selected widget
      idx = params[:widget_id].split('_').first.to_i if idx.nil?
      #saving in sandbox before deleting, to be used if discard button is pressed
      @sb[:groups] = groups
      groups.delete_at(idx) if idx
    elsif nodes.length == 3 || params[:typ] == "element"    #Remove field was pressed
      #need to delete field
      idx = nil
      fields = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
      fields.each_with_index do |field,i|
        idx = i if field[:id] == params[:widget_id].split('_').last.to_i
      end
      #if object hasn't been added to db yet, use current position to delete the selected widget
      idx = params[:widget_id].split('_').first.to_i if idx.nil?
      #saving in sandbox before deleting, to be used if discard button is pressed
      @sb[:fields] = fields
      fields.delete_at(idx) if idx
    end
    if params[:typ]
      nodes = x_node.split('_')
      nodes.pop
      self.x_node = nodes.join("_")
      @sb[:node_typ] = nil
    end
    dialog_edit_set_form_vars

    replace_right_cell(x_node, [:dialog_edit])
  end

  # Reorder dialog resources
  def dialog_res_reorder
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    @record = @edit[:dialog]
    nodes = x_node.split('_')
    if nodes.length == 1      #Reorder tabs
      temp = []
      params[:col1].each_with_index do |col,i|
        #previous position before drag-drop of the objects that came in
        pos = col.split('|').first.to_i
        temp.push(@edit[:new][:tabs][pos])
      end
      # saving original order in sandbox to be used if discard button is pressed
      @sb[:tabs] = @edit[:new][:tabs]
      @edit[:new][:tabs] = temp
    elsif nodes.length == 2   #Reorder groups
      temp = []
      params[:col1].each_with_index do |col,i|
        #previous position before drag-drop of the objects that came in
        pos = col.split('|').first.to_i
        temp.push(@edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][pos])
      end
      # saving original order in sandbox to be used if discard button is pressed
      @sb[:groups] = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups]
      @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups] = temp
    elsif nodes.length == 3   #Reorder fields
      temp = []
      params[:col1].each do |col|
        # previous position before drag-drop of the objects that came in
        pos = col.split('|').first.to_i
        temp.push(@edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields][pos])
      end
      # saving original order in sandbox to be used if discard button is pressed
      @sb[:fields] = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
      @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields] = temp
    end
    dialog_edit_build_tree
    render :update do |page|                    # Use JS to update the display
      session[:changed] = changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      page.replace_html("custom_left_cell_div", :partial=>"dialog_edit_tree")
      # url to be used in url in miqDropComplete method
      page << "miq_widget_dd_url = 'miq_ae_customization/dialog_res_reorder'"
      page << "miqInitDashboardCols();"
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to select a field value entry
  def field_value_select
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    @record = @edit[:dialog]
    if params[:entry_id] == "new"
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("field_values_div", :partial=>"field_values", :locals=>{:entry=>"new", :edit=>true})
        page << javascript_focus('entry_name')
        page << "$('entry_name').select();"
      end
      session[:entry] = "new"
    else
      entry = 0
      #dialog_sort_values
      #@edit[:field_values].each_with_index do |e, i|
      #  entry = i if e == params[:entry_id]
      #end
      entry = params[:entry_id]
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("field_values_div", :partial=>"field_values", :locals=>{:entry=>entry, :edit=>true})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('entry_#{j_str(params[:field])}').select();"

     end
      session[:entry] = entry
    end
  end

  # AJAX driven routine to add/update a field value entry
  def field_value_accept
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    @record = @edit[:dialog]
    field_value_get_form_vars
    nodes = x_node.split('_')
    fields = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
    # if field is being added then use last array element of fields as index
    id = nodes.length == 4 ? nodes[3].split('-').last.to_i : (fields.length == 0 ? 0 : fields.length-1) #set id to 0 if nothing has been added yet to array
    #one of the fields is being edited
    key = fields[id]

    if session[:entry] == "new"
      if params["entry"]["value"].strip! != "" && params["entry"]["description"].strip != ""

        if key[:values].include?([params["entry"]["value"],params["entry"]["description"]])
          add_flash(_("%{field} '%{value}' is already in use") % {:field=>params["entry"]["description"], :value=>params["entry"]["value"]}, :error)
          render_flash do |page|
            page << javascript_focus('entry_name')
          end
          return
        else
          key[:values].push([params["entry"]["value"],params["entry"]["description"]])
          @edit[:field_values] = copy_array(key[:values])
        end

      else
        add_flash(_("%{field1} and %{field2} fields can't be blank") % {:field1=>"Value", :field2=>"Description"}, :error)
        render_flash do |page|
          page << javascript_focus('entry_value')
        end
        return
      end

    else
      key[:values].each_with_index do |entry, i|

        if entry[0] == params["entry"]["value"] &&
            entry[1] == params["entry"]["description"]
          add_flash(_("%{field} '%{value}' is already in use") % {:field=>params["entry"]["description"], :value=>params["entry"]["value"]}, :error)

          render_flash do |page|
            page << javascript_focus('entry_name')
          end
          return
        else
          if i == params["entry"]["id"].to_i
            entry[0] = params["entry"]["value"]
            entry[1] = params["entry"]["description"]
            @edit[:field_values][i] = [params["entry"]["value"],params["entry"]["description"]]
          end
        end
      end

    # Build the Classification Edit screen
    end

    # Use JS to update the display
    render :update do |page|
      page.replace("field_values_div", :partial=>"field_values", :locals=>{ :entry=>nil})
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)

      # replace select tag of default values
      url = url_for(:action=>'dialog_form_field_changed', :id=>"#{@record.id || "new"}")
      none =  [['<None>', nil]]
      values = key[:values].empty? ? none : none + key[:values].collect {|val| val.reverse}
      selected = @edit[:field_default_value]
      page.replace("field_default_value",
                   :text=> "#{select_tag('field_default_value', options_for_select(values, selected), 'data-miq_observe'=>{:interval=>'.5', :url=>url}.to_json)}")
    end
  end

  # AJAX driven routine to delete a field value entry
  def field_value_delete
    field_value_get_form_vars
    @record = @edit[:dialog]
    nodes = x_node.split('_')
    fields = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
    # if field is being added then use last array element of fields as index
    id = nodes.length == 4 ? nodes[3].split('-').last.to_i : (fields.length == 0 ? 0 : fields.length-1) #set id to 0 if nothing has been added yet to array
    #one of the fields is being edited
    key = fields[id]

    # set default value to "None" if entry of def. value is removed - radio|dropdown
    if key[:typ] =~ /(Dialog|Radio)/
      if @edit[:field_default_value] == key[:values][params[:entry_id].to_i][1]
        @edit[:field_default_value] = key[:default_value] = nil
      end
    end

    key[:values].delete_at(params[:entry_id].to_i)
    @edit[:field_values].delete_at(params[:entry_id].to_i)

    # Use JS to update the display
    render :update do |page|
      page.replace("field_values_div", :partial=>"field_values", :locals=>{:entry=>nil})
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)

      # replace select tag of default values
      url = url_for(:action=>'dialog_form_field_changed', :id=>"#{@record.id || "new"}")
      none =  [['<None>', nil]]
      values = key[:values].empty? ? none : none + key[:values].collect {|val| val.reverse}
      selected = @edit[:field_default_value]
      page.replace("field_default_value",
                   :text => select_tag('field_default_value',
                                       options_for_select(values, selected),
                                       'data-miq_observe'=>{:interval=>'.5', :url=>url}.to_json))
    end
  end


  ###########################################################################
  # Automation endpoint tree support methods
  #

  def ae_tree_select_toggle
    @edit = session[:edit]
    self.x_active_tree = :dialog_edit_tree
    at_tree_select_toggle(:field_entry_point)

    if params[:button] == 'submit'
      x_node_set(@edit[:active_id], :automate_tree)

      # fixme: extract method from the following 4 lines
      nodes = x_node.split('_')
      fields = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
      id = nodes.length == 4 ? nodes[3].split('-').last.to_i : (fields.length == 0 ? 0 : fields.length-1)
      key = fields[id]
      key[:entry_point]         = @edit[:new][:field_entry_point]
      @edit[:field_entry_point] = @edit[:new][:field_entry_point]
    end

    session[:edit] = @edit
  end

  def ae_tree_select
    @edit = session[:edit]
    at_tree_select(:field_entry_point)

    session[:edit] = @edit
  end

  private     ############

  # A new classificiation field value was selected
  def field_value_new_cat
    field_value_get_form_vars
    if params[:classification_name]
      @cat = Classification.find_by_name(params["classification_name"])
      field_value_build_screen                                          # Build the Classification Edit screen
      render :update do |page|                    # Use JS to update the display
        page.replace(:tab_div, :partial=>"settings_co_tags_tab")
      end
    end
  end

  def field_value_get_form_vars
    @edit = session[:edit]
  end

  def dialog_add_box
    assert_privileges("dialog_add_box")
    dialog_res_add
  end

  def dialog_add_tab
    assert_privileges("dialog_add_tab")
    dialog_res_add
  end

  def dialog_add_element
    assert_privileges("dialog_add_element")
    dialog_res_add
  end

  def prepare_move_field_value
    @values = @edit[:field_values]
    @refresh_div = "field_values_div"
    @refresh_partial = "field_values"

    if @values.count > 1
      @idx = params[:entry_id].to_i
      # last/first item cannot be moved down/up
      if params['button'] == 'down'
        @idx = nil if @idx == @values.count - 1
      else
        @idx = nil if @idx == 0
      end
    end
  end

  def move_field_value_up
    if no_items_selected?(:entry_id)
      add_flash(_("No %s were selected to move up") %  "fields", :error)
      return
    end
    prepare_move_field_value
    @values[@idx - 1], @values[@idx] = @values[@idx], @values[@idx - 1] if @idx
  end

  def move_field_value_down
    if no_items_selected?(:entry_id)
      add_flash(_("No %s were selected to move down") %  "fields", :error)
      return
    end
    prepare_move_field_value
    @values[@idx], @values[@idx + 1] = @values[@idx + 1], @values[@idx] if @idx
  end

  # FIXME: move validations to DialogField and subclases
  def dialog_validate
    @edit = session[:edit]
    res = true
    nodes = x_node.split('_')
    if nodes.length == 1 && @sb[:node_typ].blank? #dialog is being edited
      if @edit[:new][:label].nil? || @edit[:new][:label].strip == ""
        add_flash(_("%s is required") % "Dialog Label", :error)
        res = false
      end
    elsif (nodes.length == 2 && @sb[:node_typ] != "box") || (nodes.length == 1 && @sb[:node_typ] == "tab")  #tab is being added or edited
      if @edit[:tab_label].nil? || @edit[:tab_label].strip == ""
        add_flash(_("%s is required") % "Tab Label", :error)
        res = false
      end
    elsif (nodes.length == 3 &&  @sb[:node_typ] != "element") || (nodes.length == 2 && @sb[:node_typ] == "box")         ##group is being added or edited
      if @edit[:group_label].nil? || @edit[:group_label].strip == ""
        add_flash(_("%s is required") % "Box Label", :error)
        res = false
      end
    elsif @sb[:node_typ] == "element"         ##field is being added or edited
      if @edit[:field_label].nil? || @edit[:field_label].strip == ""
        add_flash(_("%s is required") % "Element Label", :error)
        res = false
      end
      if @edit[:field_typ].to_s == 'DialogFieldDynamicList' && @edit[:field_entry_point].blank?
        add_flash(_("Entry Point must be given for field \"%s\".") %  @edit[:field_name], :error)
        res = false
      end
      if @edit[:field_name].to_s !~ %r{^[a-z0-9_]+$}i
        add_flash(_("%s must be alphanumeric characters and underscores without spaces") % "Element Name", :error)
        res = false
      end
      if ["action", "controller"].include?(@edit[:field_name].to_s)
        add_flash(_("%s must not be 'action' or 'controller'") % "Element Name", :error)
        res = false
      end
      if @edit[:field_typ].nil? || @edit[:field_typ].strip == ""
        add_flash(_("%s is required") % "Element Type", :error)
        res = false
      end
    end
    return res
  end

  # Build a Dialogs tree
  def dialog_edit_build_tree
    x_tree_init(:dialog_edit_tree, :dialog_edit, nil)
    # building tab nodes under a dialog
    tab_nodes = []
    Array(@edit[:new][:tabs]).each_with_index do |tab, i|
      tab_node = TreeNodeBuilder.generic_tree_node(
        "root_#{tab[:id]}-#{i}",
        tab[:label]       || '[New Tab]',
        "dialog_tab.png",
        tab[:label]       || '[New Tab]',
        :expand => true
      )
      self.x_node = "root_#{tab[:id]}-#{i}" unless tab[:label]

      # building group nodes under a dialog/tab
      group_nodes = []
      unless tab[:groups].blank?
        tab[:groups].each_with_index do |group, j|
          group_node = TreeNodeBuilder.generic_tree_node(
            "#{tab_node[:key]}_#{group[:id]}-#{j}",
            group[:label]       || '[New Box]',
            "dialog_group.png",
            group[:description] || group[:label],
            :expand => true
          )
          self.x_node = "#{tab_node[:key]}_#{group[:id]}-#{j}" unless group[:label]

          # building field nodes under a dialog/tab/group
          field_nodes = []
          unless group[:fields].blank?
            get_field_types
            group[:fields].each_with_index do |field, k|
              if field[:description].nil?
                field_tooltip = "#{@edit[:field_types][field[:typ]]}: #{field[:label]}"
              else
                field_tooltip = "#{@edit[:field_types][field[:typ]]}: #{field[:description]}"
              end
              field_node = TreeNodeBuilder.generic_tree_node(
                "#{group_node[:key]}_#{field[:id]}-#{k}",
                field[:label] || '[New Element]',
                "dialog_field.png",
                field_tooltip
              )
              self.x_node = "#{group_node[:key]}_#{field[:id]}-#{k}" unless field[:label]

              field_nodes.push(field_node)
            end
          end
          group_node[:children] = field_nodes unless field_nodes.empty?
          group_nodes.push(group_node)
        end
      end
      tab_node[:children] = group_nodes unless group_nodes.blank?
      tab_nodes.push(tab_node)
    end

    base_node = TreeNodeBuilder.generic_tree_node(
      "root",
      "#{@edit[:new][:label] || '[New Dialog]'}",
      "dialog.png",
      @edit[:new][:description] || @edit[:new][:label],
      :expand => true
    )

    base_node[:children] = tab_nodes unless tab_nodes.empty?

    @temp[:dialog_edit_tree] = base_node.to_json # JSON object for tree loading

    x_node_set("root", :dialog_edit_tree) unless x_node(:dialog_edit_tree)

  end

  # Get variables from edit form
  def dialog_get_form_vars
    @record = @edit[:dialog]
    nodes = x_node.split('_')

    if ["up", "down"].include?(params[:button])
      move_field_value_up   if params[:button] == "up"
      move_field_value_down if params[:button] == "down"
      # update values for selected field in @edit[:new]
      nodes = x_node.split('_')
      ids = nodes[3].split('-')
      field = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields][ids.last.to_i]
      field[:values] = copy_array(@edit[:field_values])
    end

    # dialog is being edited
    if (nodes.length == 1 && @sb[:node_typ].blank?) || (@record.id.nil? && @edit[:new][:label].nil? )
      @edit[:new][:label]       = params[:label]       if params[:label]
      @edit[:new][:description] = params[:description] if params[:description]

      params.each do |var, val|
        prefix, button = var.split('_', 2)
        if prefix == 'chkbx'
          if val == '1'
            @edit[:new][:buttons].push(button).sort! unless @edit[:new][:buttons].include?(button)
          else
            @edit[:new][:buttons].delete(button) if @edit[:new][:buttons].include?(button)
          end
        end
      end

    # tab is being added or edited
    elsif (nodes.length == 2 && @sb[:node_typ] != "box") || (nodes.length == 1 && @sb[:node_typ] == "tab")
      tabs = @edit[:new][:tabs]
      # if tab is being added then use last array element of tabs as index
      id = nodes.length == 2 ? nodes[1].split('-').last.to_i : (tabs.length == 0 ? 0 : tabs.length-1) #set id to 0 if nothing has been added yet to array
      #one of the tabs is being edited
      key = tabs[id]
      @edit[:tab_label]       = key[:label]       = params[:tab_label]       if params[:tab_label]
      @edit[:tab_description] = key[:description] = params[:tab_description] if params[:tab_description]

    # group is being added or edited
    elsif (nodes.length == 3 &&  @sb[:node_typ] != "element") || (nodes.length == 2 && @sb[:node_typ] == "box")
      groups = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups]
      # if group is being added then use last array element of groups as index
      id = nodes.length == 3 ? nodes[2].split('-').last.to_i : (groups.length == 0 ? 0 : groups.length-1) #set id to 0 if nothing has been added yet to array
      # one of the groups is being edited
      key = groups[id]
      @edit[:group_label]       = key[:label]       = params[:group_label]       if params[:group_label]
      @edit[:group_description] = key[:description] = params[:group_description] if params[:group_description]

    # field is being added or edited
    elsif @sb[:node_typ] == "element"
      dialog_get_form_vars_field
    end
  end

  # Get field-related variables from then edit form.
  def dialog_get_form_vars_field
    nodes = x_node.split('_')

    # if field is being added then use last array element of fields as index
    fields = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields]
    # set id to 0 if nothing has been added yet to array
    id = nodes.length == 4 ? nodes[3].split('-').last.to_i : (fields.length == 0 ? 0 : fields.length-1)
    # one of the fields is being edited
    key = fields[id]

    copy_field_param = proc do |param_key|
      field_key = ('field_' + param_key.to_s).to_sym
      @edit[field_key] = key[param_key] = params[field_key] if params[field_key]
    end

    copy_checkbox_field_param = proc do |param_key|
      field_key = ('field_' + param_key.to_s).to_sym
      @edit[field_key] = key[param_key] = params[field_key].to_s == '1' if params[field_key].present?
    end

    [:label, :name, :description].each { |key| copy_field_param.call(key) }

    # new dropdown/radio is being added set default options OR if existing field type has been changed to dropdown/radio
    if params[:field_typ] =~ /Drop|Radio/ && (@sb[:edit_typ] == 'add' ||
        !%w(DialogFieldDropDownList DialogFieldRadioButton).include?(@edit[:field_typ]))

      @edit[:field_required]      = key[:required]      = true
      @edit[:field_sort_by]       = key[:sort_by]       = "description"
      @edit[:field_sort_order]    = key[:sort_order]    = "ascending"
      @edit[:field_data_typ]      = key[:data_typ]      = "string"
      @edit[:field_values]        = key[:values]        = []
      @edit[:field_default_value] = key[:default_value] = nil
    end

    if @edit[:field_typ] == "DialogFieldRadioButton" && params[:field_dynamic] != true
      @edit[:field_values] ||= key[:values] = []
    end

    copy_field_param.call(:entry_point)
    copy_checkbox_field_param.call(:load_on_init)
    copy_checkbox_field_param.call(:show_refresh_button)
    copy_checkbox_field_param.call(:past_dates)
    copy_checkbox_field_param.call(:reconfigurable)
    copy_checkbox_field_param.call(:dynamic)

    [:data_typ, :required, :sort_by, :sort_by, :sort_order].each { |key| copy_field_param.call(key) }

    # set default value - element type was added/changed
    if params[:field_typ]

      # added TagControl - initialize values
      if params[:field_typ].include?("Tag")
        @edit[:field_category]     = key[:category]     = nil
        @edit[:field_single_value] = key[:single_value] = true
        @edit[:field_required]     = key[:required]     = false
        @edit[:field_values]       = key[:values]       = []
        @edit[:field_sort_by]      = key[:sort_by]      = 'description'
        @edit[:field_sort_order]   = key[:sort_order]   = 'ascending'
        @edit[:field_data_typ]     = key[:data_typ]     = 'string'
      end

      if @edit[:field_typ] != params[:field_typ]
        if params[:field_typ].include?("TextBox")
          @edit[:field_protected]      = key[:protected] = false
          @edit[:field_validator_type] = key[:validator_type] = nil
          @edit[:field_validator_rule] = key[:validator_rule] = nil
        end
        if params[:field_typ] =~ /Text/
          @edit[:field_default_value] = key[:default_value] = ''
          @edit[:field_required]      = key[:required]  = false
        elsif params[:field_typ] =~ /Drop|Radio/
          @edit[:field_default_value] = key[:default_value] = nil
        elsif params[:field_typ] =~ /DialogFieldDynamicList/
          @edit[:field_entry_point]         = key[:entry_point] = ''
          @edit[:field_show_refresh_button] = key[:show_refresh_button] = false
          @edit[:field_load_on_init]        = key[:load_on_init] = false
        else
          @edit[:field_default_value] = key[:default_value] = false
        end
      end

    # element type was NOT changed and is present
    elsif !@edit[:field_typ].blank?
      # set default_value - checkbox
      if @edit[:field_typ] =~ /Check/
        if params[:field_default_value]
          @edit[:field_default_value] = key[:default_value] = params[:field_default_value] == '1' if params[:field_default_value]
        else
          @edit[:field_default_value] ||= false
          key[:default_value] ||= false
        end
      end

      # set default value - textbox, textarea
      if @edit[:field_typ].include?('Text')

        # copy protected default value
        params[:field_default_value] = params[:field_default_value__protected] if params[:field_default_value__protected]

        if params[:field_default_value]
          @edit[:field_default_value] = key[:default_value] = params[:field_default_value]
        else
          @edit[:field_default_value] ||= ""
          key[:default_value] ||= ""
        end

        if params[:field_required]
          @edit[:field_required] = key[:required] = (params[:field_required] == "true")
        end
      end

      if @edit[:field_typ].include?('TextBox')
        if params[:field_protected]
          @edit[:field_protected] = key[:protected] = (params[:field_protected] == "true")
        else
          @edit[:field_protected] ||= false
          key[:protected] ||= false
        end
        [:validator_type, :validator_rule].each do |name|
          field_name = "field_#{name}".to_sym
          @edit[field_name] = key[name] = params[field_name] if params[field_name]
        end
      end

      # set default value - dropdown, radio
      if @edit[:field_typ] =~ /Drop|Radio/
        if params[:field_default_value]
          @edit[:field_default_value] = key[:default_value] =
            params[:field_default_value] == "" ? nil : params[:field_default_value]
        else
          @edit[:field_default_value] ||= nil
          key[:default_value] ||= nil
        end
      end

      if @edit[:field_typ].include?("TagControl")
        if params[:field_category]
          @edit[:field_category] = key[:category] = params[:field_category]
        end

        if params[:field_single_value]
          @edit[:field_single_value] = key[:single_value] = (params[:field_single_value] == "true")
        end

        if params[:field_required]
          @edit[:field_required] = key[:required] = (params[:field_required] == "true")
        end

        @edit[:field_sort_by]    = key[:sort_by]    = params[:field_sort_by]  if params[:field_sort_by]
        @edit[:field_sort_order] = key[:sort_order] = params[:sort_order]     if params[:sort_order]
        @edit[:field_data_typ]   = key[:data_typ]   = params[:field_data_typ] if params[:data_typ]
      end
    end

    copy_field_param.call(:typ)
  end

  def dialog_edit_set_form_vars
    #if coming in after tree_select in edit tree, reset edit from session
    @edit = session[:edit]
    @record = @edit[:dialog]
    @in_a_form = true
    nodes = x_node.split('_')

    if nodes.length == 1
      #@edit[:new][:label] = @record.label
      #@edit[:new][:description] = @record.description
      @sb[:node_typ] = nil if params[:action] != "dialog_form_field_changed"

    elsif nodes.length == 2
      #set name/description for selected tab
      ids = nodes[1].split('-')
      tab = @edit[:new][:tabs][ids.last.to_i]
      @edit[:tab_label]       = tab[:label]
      @edit[:tab_description] = tab[:description]
      @sb[:node_typ] = "tab" if params[:action] != "dialog_form_field_changed"

    elsif nodes.length == 3
      ids = nodes[2].split('-')
      group = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][ids.last.to_i]
      #set name/description for selected group
      @edit[:group_label]       = group[:label]
      @edit[:group_description] = group[:description]
      @sb[:node_typ] = "box" if params[:action] != "dialog_form_field_changed"

    elsif nodes.length == 4
      #set name/description for selected field
      ids = nodes[3].split('-')
      get_field_types
      field = @edit[:new][:tabs][nodes[1].split('-').last.to_i][:groups][nodes[2].split('-').last.to_i][:fields][ids.last.to_i]
      @edit.update(
        :field_label          => field[:label],
        :field_name           => field[:name],
        :field_description    => field[:description],
        :field_typ            => field[:typ],
        :field_dynamic        => field[:dynamic],
        :field_default_value  => field[:default_value],
        :field_reconfigurable => field[:reconfigurable],
        :field_required       => field[:required]
      )

      if field[:typ].include?('TextBox')
        @edit[:field_protected]      = field[:protected]
        @edit[:field_validator_type] = field[:validator_type]
        @edit[:field_validator_rule] = field[:validator_rule]
      end
      @edit[:field_required]  = field[:required]  if field[:typ].include?('Text')

      if field[:typ].include?("TagControl")
        @edit[:field_single_value] = field[:single_value]
        @edit[:field_category]     = field[:category]
      end

      if dynamic_field?(field)
        @edit.update(
          :field_load_on_init        => field[:load_on_init],
          :field_show_refresh_button => field[:show_refresh_button],
          :field_entry_point         => field[:entry_point],
        )
      end

      if %w(DialogFieldTagControl DialogFieldDropDownList DialogFieldRadioButton).include?(field[:typ])
        @edit.update(
          :field_required   => field[:required],
          :field_sort_by    => field[:sort_by]    ? field[:sort_by].to_s    : "description",
          :field_sort_order => field[:sort_order] ? field[:sort_order].to_s : "ascending",
          :field_data_typ   => field[:data_typ],
          :field_values     => field[:values]     ? copy_array(field[:values]) : []
        )
      elsif %w(DialogFieldDateControl DialogFieldDateTimeControl).include?(field[:typ])
        @edit[:field_past_dates] = field[:past_dates]
      end

      @sb[:node_typ] = "element" if params[:action] != "dialog_form_field_changed"
    end
    dialog_edit_build_tree
    session[:changed] = (@edit[:new] != @edit[:current])
    session[:edit] = @edit
  end

  def get_field_types
    @edit[:field_types] = copy_hash(DialogField.dialog_field_types)
    @edit[:new][:tabs].each do |tab|
      if tab[:groups]
        tab[:groups].each do |group|
          if group[:fields]
            group[:fields].each do |field|
              # if field being edited/displayed is date/time no need to delete it from array
              # incase user wants to change the type
              # don't remove from array if field being added in Date/time field
              if !["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(@edit[:field_typ]) &&
                  ["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(field[:typ]) &&
                  !["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(params[:field_typ])
                @edit[:field_types].delete("DialogFieldDateControl")
                @edit[:field_types].delete("DialogFieldDateTimeControl")
                break
              end
            end
          end
        end
      end
    end
  end

  # Set initial form variables for edit
  def dialog_set_form_vars
    self.x_active_tree = :dialog_edit_tree
    @sb[:edit_typ] = nil
    @in_a_form = true
    @edit = {}
    @edit[:dialog] = @record
    @edit[:rec_id] = @record.try(:id)
    @edit[:current] = {}
    @edit[:key] = "dialog_edit__#{@record.id || "new"}"

    @edit[:new] = {
      :label       => @record.label,
      :description => @record.description,
      :buttons     => @record.buttons ? @record.buttons.split(/\s*,\s*/).sort : [],
    }

    # want support the others buttons in future
    #@edit[:dialog_buttons] = ["save","submit","continue","reset","cancel"]
    @edit[:dialog_buttons] = ["submit", "cancel"]

    #setting tabs
    @edit[:new][:tabs] = []

    unless @record.ordered_dialog_resources.empty?
      @record.ordered_dialog_resources.each_with_index do |tab,i|
        t = tab.resource
        groups = []

        # setting group for tabs
        t.ordered_dialog_resources.each_with_index do |group,j|
          g = group.resource
          fields = []

          # setting fields for a tab/group
          g.ordered_dialog_resources.each do |field|
            f = field.resource
            fld = {
              :id             => f.id,
              :label          => f.label,
              :description    => f.description,
              :typ            => f.type,
              :tab_id         => t.id,
              :group_id       => g.id,
              :order          => field.order,
              :name           => f.name,
              :reconfigurable => f.reconfigurable,
              :dynamic        => f.dynamic
            }

            if dynamic_field?(f)
              fld.update(
                :load_on_init        => f.load_values_on_init,
                :show_refresh_button => f.show_refresh_button,
                :entry_point         => f.resource_action.fqname
              )
            end

            if %w(DialogFieldDropDownList DialogFieldRadioButton).include?(f.type)
              fld.update(
                :required      => f.required.nil? ? true : f.required,
                :sort_by       => f.sort_by       ? f.sort_by.to_s    : "description",
                :sort_order    => f.sort_order    ? f.sort_order.to_s : "ascending",
                :data_typ      => f.data_type     ? f.data_type       : "string",
                :values        => f.values        ? copy_array(f.values) : [],
                :default_value => f.default_value
              )
            end

            if f.type == "DialogFieldCheckBox"
              fld[:default_value] = f.default_value.to_s != "f"
              fld[:required] = !!f.required

            elsif f.type.include?("Text")
              if f.type.include?('TextBox')
                fld[:protected]      = f.protected?
                fld[:validator_type] = f.validator_type
                fld[:validator_rule] = f.validator_rule
              end
              fld[:required]      = f.required
              fld[:default_value] = f.default_value.nil? ? "": f.default_value

            elsif ["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(f.type)
              fld[:past_dates] = f.show_past_dates.nil? ? false : f.show_past_dates

            elsif f.type.include?("TagControl")
              fld[:single_value] = f.single_value?
              fld[:required]     = f.required
              fld[:sort_by]      = f.sort_by    ? f.sort_by.to_s    : "description"
              fld[:sort_order]   = f.sort_order ? f.sort_order.to_s : "ascending"
              fld[:data_typ]     = f.data_type
              fld[:category]     = f.category
            end

            fields.push(fld)
          end
          groups.push({
            :id          => g.id,
            :label       => g.label,
            :description => g.description,
            :tab_id      => t.id,
            :order       => group.order,
            :fields      => fields
          })
        end

        @edit[:new][:tabs].push({:id=>t.id, :label=>t.label, :description=>t.description, :order=>tab.order, :groups=>groups})
      end
    end

    @edit[:current] = copy_hash(@edit[:new])
    dialog_edit_build_tree
    x_node_set("root", :dialog_edit_tree)     #always set it to root for edit tree

    session[:edit] = @edit
  end

  def dialog_set_record_vars(dialog)
    dialog.label       = @edit[:new][:label]
    dialog.description = @edit[:new][:description]
    temp_buttons = []

    #Making sure buttons are saved in correct order
    @edit[:dialog_buttons].each do |b|
      temp_buttons.push(b) if @edit[:new][:buttons].include?(b)
    end

    dialog.transaction do
      dialog.buttons = temp_buttons.join(',')
      dialog.remove_all_resources if dialog.id

      if @edit[:new][:tabs]
        @edit[:new][:tabs].each_with_index do |tab,i|
          dt = DialogTab.new(:label => tab[:label], :description => tab[:description], :display => :edit)
          dialog.add_resource(dt, {:order => i})

          if tab[:groups]
            tab[:groups].each_with_index do |group,j|
              dg = DialogGroup.new(:label => group[:label], :description => group[:description], :display => :edit)
              dt.add_resource(dg, {:order => j})

              if group[:fields]
                group[:fields].each_with_index do |field,k|
                  fld = {
                    :label          => field[:label],
                    :description    => field[:description],
                    :name           => field[:name],
                    :reconfigurable => field[:reconfigurable],
                    :dynamic        => field[:dynamic],
                    :display        => :edit
                  }

                  if field[:typ] =~ /Drop|Radio/ && field[:dynamic] != true
                    fld.update(
                      :required      => field[:required],
                      :sort_by       => field[:sort_by].to_sym,
                      :sort_order    => field[:sort_order].to_sym,
                      :data_type     => field[:data_typ],
                      :values        => field[:values],
                      :default_value => field[:default_value]
                    )
                  end

                  if dynamic_field?(field)
                    fld[:values]              = []
                    fld[:load_values_on_init] = field[:load_on_init]
                    fld[:show_refresh_button] = field[:show_refresh_button]

                  elsif field[:typ] == "DialogFieldCheckBox"
                    fld[:default_value] = field[:default_value]
                    fld[:required] = field[:required]

                  elsif field[:typ] =~ /Text/
                    if field[:typ].include?('TextBox')
                      fld[:protected]      = field[:protected]
                      fld[:validator_type] = field[:validator_type]
                      fld[:validator_rule] = field[:validator_rule]
                    end
                    fld[:required]      = field[:required]  if field[:typ].include?('Text')
                    fld[:default_value] = field[:default_value].to_s

                  elsif ["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(field[:typ])
                    fld[:show_past_dates] = field[:past_dates]

                  elsif field[:typ].include?("TagControl")
                    fld.update(
                      :category           => field[:category],
                      :required           => field[:required],
                      :force_single_value => field[:single_value],
                      :data_type          => field[:data_typ],
                      :sort_by            => field[:sort_by].to_sym,
                      :sort_order         => field[:sort_order].to_sym
                    )
                  end

                  df = field[:typ].constantize.new(fld)
                  df.resource_action.fqname = field[:entry_point] if dynamic_field?(field)
                  dg.add_resource(df, {:order => k})
                end
              end
            end
          end
        end
      end

      if dialog.dialog_fields.blank?
        raise "Dialog must have at least one Element"
      else
        dialog.save!
      end
    end
  end

  # Common Schedule button handler routines
  def process_dialogs(dialogs, task)
    process_elements(dialogs, Dialog, task)
  end

  # Common VM button handler routines
  def dialog_button_operation(method, display_name)
    dialogs = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      dialogs = find_checked_items
      if dialogs.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:model=>"Dialog"), :task=>display_name}, :error)
      else
        process_dialogs(dialogs, method)
      end
      get_node_info
      replace_right_cell(x_node,[:dialogs])
    else # showing 1 dialog
      if params[:id].nil? || Dialog.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:model=>"Dialog"), :error)
        dialog_list
        @refresh_partial = "layouts/gtl"
      else
        dialogs.push(params[:id])
        process_dialogs(dialogs, method)  unless dialogs.empty?
        # TODO: tells callers to go back to show_list because this SMIS Agent may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "root"
        end
        get_node_info
        replace_right_cell(x_node,[:dialogs])
      end
    end
    return dialogs.count
  end

  def dialog_get_node_info(treenodeid)
    if treenodeid == "root"
      dialog_list
      @right_cell_text = _("All %s") % ui_lookup(:models=>"Dialog")
    else
      @sb[:active_tab] = "sample_tab" if !params[:tab_id]     #reset active tab if not coming in from change_tab
      @record = Dialog.find_by_id(from_cid(treenodeid.split('-').last))
      if @record.nil?
        @replace_tree = true      #refresh tree and go back to root node if previously selected dialog record is deleted outside UI from vmdb
        self.x_node = "root"
        dialog_get_node_info(x_node)
      else
        @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"Dialog"), :name=>@record.label}
      end
    end
  end

  def dynamic_field?(field)
    field[:typ] == 'DialogFieldDynamicList' || field[:dynamic]
  end
end
