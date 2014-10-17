module OpsController::Settings::AnalysisProfiles
  extend ActiveSupport::Concern

  # Show scanitemset list view
  def aps_list
    ap_build_list

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace_html("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"aps_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  # Show a scanitemset
  def ap_show
    @new_gtl_type = params[:type] if params[:type]  # Set new list view type, if it's sent in
    #identify_scanitemset
    if @selected_scan == nil
      redirect_to :action=>"show_list_set", :flash_msg=>I18n.t("flash.error_no_longer_exists"), :flash_error=>true
      return
    end
    @lastaction = "ap_show"

    @selected_scan.members.each do | a |
      case a.item_type
      when "category"
        @category = Array.new if @category.nil?
        for i in 0...a[:definition]["content"].length
          @category.push(CATEGORY_CHOICES[a[:definition]["content"][i]["target"]]) if a[:definition]["content"][i]["target"] != "vmevents"
        end
      when "file"
        @file = Array.new if @file.nil?
        @file_stats = Hash.new
        for i in 0...a[:definition]["stats"].length
          @file_stats["#{a[:definition]["stats"][i]["target"]}"] = a[:definition]["stats"][i]["content"] ? a[:definition]["stats"][i]["content"] : false
          @file.push(a[:definition]["stats"][i]["target"])
        end
      when "registry"
        @registry = Array.new if @registry.nil?
        for i in 0...a[:definition]["content"].length
          @registry.push(a[:definition]["content"][i])
        end
      when "nteventlog"
        @nteventlog = Array.new if @nteventlog.nil?
        for i in 0...a[:definition]["content"].length
          @nteventlog.push(a[:definition]["content"][i])
        end
      end
    end
  end

  def ap_ce_select
    return unless load_edit("ap_edit__#{params[:id]}","replace_cell__explorer")
    ap_get_form_vars
    if params[:edit_entry] == "edit_file"
      session[:edit_filename] = params[:file_name]
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace_html("ap_form_div", :partial=>"ap_form", :locals=>{:entry=>session[:edit_filename], :edit=>true})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('entry_#{j_str(params[:field])}').select();"
      end
    elsif params[:edit_entry] == "edit_registry"
      session[:reg_data] = Hash.new
      session[:reg_data][:key] = params[:reg_key]  if params[:reg_key]
      session[:reg_data][:value] = params[:reg_value] if params[:reg_value]
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("ap_form_div", :partial=>"ap_form", :locals=>{:entry=>session[:reg_data], :edit=>true})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('entry_#{j_str(params[:field])}').select();"
      end
    elsif params[:edit_entry] == "edit_nteventlog"
      session[:nteventlog_data] = Hash.new
      session[:nteventlog_entries].sort_by { |r| r[:name] }.each_with_index do |nteventlog,i|
        if i == params[:entry_id].to_i
          session[:nteventlog_data][:selected] = i
          session[:nteventlog_data][:name] = nteventlog[:name]
          session[:nteventlog_data][:message] = nteventlog[:filter][:message]
          session[:nteventlog_data][:level] = nteventlog[:filter][:level]
          session[:nteventlog_data][:num_days] = nteventlog[:filter][:num_days].to_i
          #session[:nteventlog_data][:rec_count] = nteventlog[:filter][:rec_count].to_i
          session[:nteventlog_data][:source] = nteventlog[:filter][:source]
        end
      end

      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("ap_form_div", :partial=>"ap_form", :locals=>{:entry=>session[:nteventlog_data], :edit=>true})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('entry_#{j_str(params[:field])}').select();"
      end
    else
      session[:edit_filename] = ""
      session[:reg_data] = Hash.new
      session[:nteventlog_data] = Hash.new
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("ap_form_div", :partial=>"ap_form", :locals=>{:entry=>"new", :edit=>true})
        page << javascript_focus('entry_name')
        page << "$('entry_name').select();"
      end
    end
  end

  # AJAX driven routine to delete a classification entry
  def ap_ce_delete
    return unless load_edit("ap_edit__#{params[:id]}","replace_cell__explorer")
    ap_get_form_vars
    if params[:item1] == "registry"
      session[:reg_entries].each do | reg |
        if reg.has_value?(params[:reg_key]) && reg.has_value?(params[:reg_value])
          session[:reg_entries].delete(reg)
        end
      end
      @edit[:new]["registry"][:definition]["content"].each do |reg_keys|
        if reg_keys["key"] == params[:reg_key] && reg_keys["value"] == params[:reg_value]
          @edit[:new]["registry"][:definition]["content"].delete(reg_keys)
        end
      end
    elsif params[:item2] == "nteventlog"
      session[:nteventlog_entries].sort_by { |r| r[:name] }.each_with_index do |nteventlog,i|
        if i == params[:entry_id].to_i
          session[:nteventlog_entries].delete(nteventlog)
          @edit[:nteventlog_entries].delete(nteventlog) if !@edit[:nteventlog_entries].blank?
        end
      end
      @edit[:new]["nteventlog"][:definition]["content"].sort_by { |r| r[:name] }.each_with_index do |nteventlog_keys,i|
        if nteventlog_keys[:name] == params[:nteventlog_name] && i == params[:entry_id].to_i
          @edit[:new]["nteventlog"][:definition]["content"].delete(nteventlog_keys)
        end
      end
    else
      session[:file_names].each do |file_name|
        if file_name["target"] == params[:file_name]
          session[:file_names].delete(file_name)
        end
      end
      @edit[:new]["file"][:definition]["stats"].each do |fname|
        if fname["target"] == params[:file_name]
          @edit[:new]["file"][:definition]["stats"].delete(fname)
        end
      end
    end
    @edit[:new] = ap_sort_array(@edit[:new])
    @edit[:current] = ap_sort_array(@edit[:current])
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page.replace("ap_form_div", :partial=>"ap_form", :locals=>{:entry=>"new", :edit=>false})
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Build the audit object when a record is created, including all of the new fields
  def ap_build_created_audit_set(scanitemset)
    msg = "[#{scanitemset.name}] Record created ("
    event = "scanitemset_record_add"
    i = 0
    @edit[:new].each_key do |k|
      msg = msg + ", " if i > 0
      i += 1
      if k == :members    # Check for members array
        msg = msg +  k.to_s + ":[" + @edit[:new][k].keys.join(",") + "]"
      else
        msg = msg +  k.to_s + ":[" + @edit[:new][k].to_s + "]"
      end
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>scanitemset.id, :target_class=>scanitemset.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  # Build the audit object when a record is saved, including all of the changed fields
  def ap_build_saved_audit(scanitemset)
    msg = "[#{scanitemset.name}] Record updated ("
    event = "scanitemset_record_update"
    i = 0
    @edit[:new].each_key do |k|
      if @edit[:new][k] != @edit[:current][k]
        msg = msg + ", " if i > 0
        i += 1
          msg = msg +  k.to_s + ":[" + @edit[:current][k].to_s + "] to [" + @edit[:new][k].to_s + "]"
      end
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>scanitemset.id, :target_class=>scanitemset.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  def ap_copy
    assert_privileges("ap_copy")
    @_params[:typ] = "copy"
    ap_edit
  end

  def ap_host_edit
    assert_privileges("ap_host_edit")
    @_params[:typ] = "Host"
    ap_edit
  end

  def ap_vm_edit
    assert_privileges("ap_vm_edit")
    @_params[:typ] = "Vm"
    ap_edit
  end

  def ap_edit
    assert_privileges("ap_edit")
    if params["accept"]
      ap_accept_line_changes
    else
      case params[:button]
      when "cancel"
        @scan = ScanItemSet.find_by_id(session[:edit][:scan_id]) if session[:edit][:scan_id]
        if @scan
          add_flash(I18n.t("flash.edit.cancelled",
                        :model=>ui_lookup(:model=>"ScanItemSet"), :name=>@scan.name))
        else
          add_flash(I18n.t("flash.add.cancelled",
                           :model=>ui_lookup(:model=>"ScanItemSet")))
        end
        get_node_info(x_node)
#       @scan = @edit[:scan] = nil
        @scan = nil
#       @edit = session[:edit] = nil  # clean out the saved info
        replace_right_cell(@nodetype)
      when "save", "add"
        id = params[:button] == "add" ? "new" : params[:id]
        return unless load_edit("ap_edit__#{id}","replace_cell__explorer")
        @scan = ScanItemSet.find_by_id(@edit[:scan_id])
        ap_get_form_vars
        if (@edit[:new]["category"].nil? || @edit[:new]["category"][:definition]["content"].length == 0) &&
            (@edit[:new]["file"].nil? || @edit[:new]["file"][:definition]["stats"].length == 0) &&
            (@edit[:new]["registry"].nil? || @edit[:new]["registry"][:definition]["content"].length == 0) &&
            (@edit[:new]["nteventlog"].nil? || @edit[:new]["nteventlog"][:definition].nil? || @edit[:new]["nteventlog"][:definition]["content"].length == 0)
          add_flash(I18n.t("flash.ops.settings.at_least_1_item_required"), :error)
          @sb[:miq_tab] = @edit[:new][:scan_mode] == "Host" ? "edit_2" : "edit_1"
          @edit[:new] = ap_sort_array(@edit[:new])
          @edit[:current] = ap_sort_array(@edit[:current])
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          #ap_build_edit_screen
          #replace_right_cell("root",[:settings])
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        else
          scanitemset = params[:button] == "add" ? ScanItemSet.new : ScanItemSet.find_by_id(@edit[:scan_id])    # get the current record
          ap_set_record_vars_set(scanitemset)

          if scanitemset.valid? && !@flash_array
            scanitemset.save
            mems = scanitemset.members
            ap_set_record_vars(mems, scanitemset)
            begin
              #mems.each { |c| scanitemset.remove_member(ScanItem.find(c)) if !mems.include?(c.id) }
              #scanitemset.remove_all_members
              #scanitemset.add_member()
            rescue StandardError => bang
              title = params[:button] == "add" ? "add" : "update"
              add_flash(I18n.t("flash.error_during", :task=>title) << bang.message, :error)
            end
            if params[:button] == "save"
              AuditEvent.success(ap_build_saved_audit(scanitemset))
            else
              AuditEvent.success(ap_build_created_audit_set(scanitemset))
            end
            add_flash(I18n.t("flash.edit.saved",
                            :model=>ui_lookup(:model=>"ScanItemSet"), :name=>@edit[:new][:name]))
            aps_list
            @scan = @edit[:scan_id] = nil
            @edit = session[:edit] = nil  # clean out the saved info
            self.x_node = "xx-sis" if params[:button] == "add"
            get_node_info(x_node)
            replace_right_cell(x_node,[:settings])
          else
            scanitemset.errors.each do |field,msg|
              add_flash("#{field.to_s.capitalize} #{msg}", :error)
            end
            @edit[:new] = ap_sort_array(@edit[:new])
            @edit[:current] = ap_sort_array(@edit[:current])
            @changed = session[:changed] = (@edit[:new] != @edit[:current])
            #ap_build_edit_screen
            render :update do |page|
              page.replace("flash_msg_div", :partial => "layouts/flash_msg")
            end
          end
        end
      when "reset", nil
        @obj = find_checked_items
        @obj[0] = params[:id] if @obj.blank? && params[:id] && (params[:button] == "reset" || ["ap_copy","ap_edit"].include?(@sb[:action]))
        if !params[:tab] && params[:typ] != "copy" # if tab was not changed
          if !params[:typ] || params[:button] == "reset"
            @scan = ScanItemSet.find(@obj[0])           # Get existing or new record
            @sb[:miq_tab] = @scan.mode == "Host" ? "edit_2" : "edit_1"
            if @scan.read_only
              add_flash(I18n.t("flash.cant_edit_sample", :model=>ui_lookup(:model=>"ScanItemSet"), :name=>@scan.name), :error)
              get_node_info(x_node)
              replace_right_cell(@nodetype)
              return
            end
          else
            @scan = ScanItemSet.new           # Get existing or new record
            @scan.mode = params[:typ] if params[:typ]
            @sb[:miq_tab] = @scan.mode == "Host" ? "new_2" : "new_1"
            @edit = session[:edit]
          end
        end
        if params[:typ] == "copy"
          session[:set_copy] = "copy"
          scanitemset = ScanItemSet.find(@obj[0])
          @scan = ScanItemSet.new
          @scan.name = "Copy of " + scanitemset.name
          @scan.description = scanitemset.description
          @scan.mode = scanitemset.mode
          ap_set_form_vars
          scanitems = scanitemset.members     # Get the member sets
          scanitems.each_with_index do |scanitem, i|
            @edit[:new][scanitem.item_type] = Hash.new
            @edit[:new][scanitem.item_type][:name] = scanitem.name
            @edit[:new][scanitem.item_type][:description] = scanitem.description
            @edit[:new][scanitem.item_type][:definition] = scanitem.definition
            @edit[:new][scanitem.item_type][:type] = scanitem.item_type
            session[:file_names] = @edit[:new][scanitem.item_type][:definition]["stats"].dup if !@edit[:new][scanitem.item_type][:definition]["stats"].nil?
            session[:reg_entries] = @edit[:new]["registry"][:definition]["content"].dup if !@edit[:new]["registry"].nil?
            session[:nteventlog_entries] = @edit[:new]["nteventlog"][:definition]["content"].dup if !@edit[:new]["nteventlog"].nil?
          end
          @sb[:miq_tab] = @scan.mode == "Host" ? "edit_2" : "edit_1"
        else
          ap_set_form_vars if !params[:tab]
        end
        if params[:tab]   #only if tab was changed
          return unless load_edit("ap_edit__#{params[:id]}","replace_cell__explorer")
        end
        ap_build_edit_screen
        @sb[:ap_active_tab] = @edit[:new][:scan_mode] == "Host" ? "file" : "category"
        if params[:button] == "reset"
          add_flash(I18n.t("flash.edit.reset"), :warning)
        end
        @edit[:new] = ap_sort_array(@edit[:new])
        @edit[:current] = ap_sort_array(@edit[:current])
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        replace_right_cell("sie")
      end
    end
  end

  def ap_set_active_tab
    @sb[:ap_active_tab] = params[:tab_id]
    @edit = session[:edit]
    @scan = session[:edit][:scan]
    render :update do |page|                      # Use JS to update the display
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def ap_form_field_changed
    return unless load_edit("ap_edit__#{params[:id]}","replace_cell__explorer")
    ap_get_form_vars
    @edit[:new] = ap_sort_array(@edit[:new])
    @edit[:current] = ap_sort_array(@edit[:current])
    changed = (@edit[:new] != @edit[:current])
    ap_build_edit_screen

    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
    end
  end

  # Delete all selected or single displayed scanitemset(s)
  def ap_delete
    assert_privileges("ap_delete")
    scanitemsets = Array.new
    if !params[:id] # showing a list
      scanitemsets = find_checked_items
      if scanitemsets.empty?
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:models=>"ScanItemSet"), :task=>"deletion"), :error)
      else
        to_delete = Array.new
        scanitemsets.each do |s|
          scan = ScanItemSet.find(s)
          if scan.read_only
            to_delete.push(s)
            add_flash(I18n.t("flash.cant_delete_sample", :model=>ui_lookup(:model=>"ScanItemSet"), :name=>scan.name), :error)
          end
        end
        #deleting elements in temporary array, had to create temp array to hold id's to be delete, .each gets confused if i deleted them in above loop
        to_delete.each do |a|
          scanitemsets.delete(a)
        end
      end
      @flash_error =true  if scanitemsets.empty?
      scanitemsets.each do | id |
        itemset = ScanItemSet.find(id)
        mems = itemset.members
        mems_to_delete = Array.new
        mems.each do |m|
          mems_to_delete.push(m)
        end
        ap_deletescanitems(mems_to_delete)
        #resetting flash_array to prevent from showing message from deleting each scanitem under scanitemset
        @flash_array = Array.new
        itemset.remove_all_members
      end
      ap_process_scanitemsets(scanitemsets, "destroy")  unless scanitemsets.empty?
    else # showing 1 scanitemset, delete it
      if params[:id] == nil || ScanItemSet.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup(:model=>"ScanItemSet")), :error)
      else
        scanitemsets.push(params[:id])
      end
      @single_delete = true
      ap_process_scanitemsets(scanitemsets, "destroy")  if ! scanitemsets.empty?
      add_flash(I18n.t("flash.record.deleted_for_1_record", :model=>ui_lookup(:models=>"ScanItemSet"))) if @flash_array == nil
    end
    self.x_node = "xx-sis"
    get_node_info(x_node)
    replace_right_cell(x_node,[:settings])
  end

  private

  def ap_accept_line_changes
    return unless load_edit("ap_edit__#{params[:id]}","replace_cell__explorer")
    ap_get_form_vars
    @edit[:new] = ap_sort_array(@edit[:new])
    @edit[:current] = ap_sort_array(@edit[:current])
    @changed = session[:changed] = (@edit[:new] != @edit[:current])
    render :update do |page|                        # Use JS to update the display
      page.replace("ap_form_div", :partial=>"ap_form")
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  # Create the view and associated vars for the ap list
  def ap_build_list
    @lastaction = "aps_list"
    @force_no_grid_xml = true
    @view, @pages = get_view(ScanItemSet) # Get the records (into a view) and the paginator
    @ajax_paging_buttons = true
    @current_page = @pages[:current] if @pages != nil # save the current page number
  end

  # Copy a hash, duplicating any embedded hashes/arrays contained within
  def ap_sort_array(hashin, skip_key = nil)
    hashout = Hash.new
    hashin.each do |key,value|
      if skip_key && key == skip_key      # Skip this key, if passed in
        next
      elsif value.is_a?(Hash)
        hashout[key] = ap_sort_array(value, skip_key)
      elsif value.is_a?(Array)
        @items = Array.new
        value.sort_by { |item|
          if item.has_key?("target")
            item["target"].to_s
          elsif item.has_key?(:name)
            item[:name].to_s
          else
            item["key"].to_s
          end
        }.each do |arr|
          @items.push(arr)
        end
        hashout[key] = @items
      else
        hashout[key] = value
      end
    end
    return hashout
  end

  # Set record variables to new values
  def ap_set_record_vars_set(scanitemset)
    scanitemset.name = @edit[:new][:name].strip
    scanitemset.description = @edit[:new][:description].strip
    scanitemset.mode = @edit[:new][:scan_mode]
  end

  # Set record variables to new values
  def ap_set_record_vars(mems, scanitemset)
    unless mems.empty?
      mems_to_delete = Array.new
      mems.each { |m| mems_to_delete.push(m) }
      ap_deletescanitems(mems_to_delete)
      scanitemset.remove_all_members
    end

    [
      ["category",   "content"],
      ["file",       "stats"],
      ["registry",   "content"],
      ["nteventlog", "content"]
    ].each do |key, definition_key|
      unless @edit[:new][key].blank?
        scanitem             = ScanItem.new
        scanitem.name        = "#{scanitemset.name}_#{@edit[:new][key][:type]}"
        scanitem.description = "#{scanitemset.description} #{@edit[:new][key][:type]} Scan"
        scanitem.item_type   = @edit[:new][key][:type]
        scanitem.definition  = copy_hash(@edit[:new][key][:definition])
        unless scanitem.definition[definition_key].empty?
          begin
            scanitem.save
            scanitemset.add_member(scanitem)
            #resetting flash_array to not show a message for each memmber that is saved for a scanitemset
            @flash_array = Array.new
          rescue StandardError => bang
            add_flash(I18n.t("flash.record.error_during_task",
                            :model=>ui_lookup(:model=>"ScanItemSet"), :name=>scanitem.name, :task=>"update") << bang.message,
                      :error)
          end
        end
      end
    end

  end

  # Set form variables for edit
  def ap_set_form_vars
    @edit = Hash.new
    session[:file_names] = Array.new
    session[:reg_entries] = Array.new
    session[:nteventlog_entries] = Array.new
    @edit[:scan_id] = @scan.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "ap_edit__#{@scan.id || "new"}"

    @edit[:new][:name] = @scan.name
    @edit[:new][:scan_mode] = @scan.mode
    @edit[:new][:description] = @scan.description

    scanitems = @scan.members     # Get the member sets

    #@edit[:new][:items] = Array.new
    scanitems.each_with_index do |scanitem, i|
      @edit[:new][scanitem.item_type] = Hash.new
    # @edit[:new][scanitem.item_type][:id] = scanitem.id
      @edit[:new][scanitem.item_type][:name] = scanitem.name
      @edit[:new][scanitem.item_type][:description] = scanitem.description
      @edit[:new][scanitem.item_type][:definition] = scanitem.definition.dup
      @edit[:new][scanitem.item_type][:type] = scanitem.item_type
      session[:file_names] = @edit[:new][scanitem.item_type][:definition]["stats"].dup if !@edit[:new][scanitem.item_type][:definition]["stats"].nil?
      session[:reg_entries] = @edit[:new]["registry"][:definition]["content"].dup if !@edit[:new]["registry"].nil?
      session[:nteventlog_entries] = @edit[:new]["nteventlog"][:definition]["content"].dup if !@edit[:new]["nteventlog"].nil?
    end

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def ap_get_form_vars_category
    item_type = params[:item_type]
    @edit[:new][item_type] ||= Hash.new
    @edit[:new][item_type][:type] = params[:item_type]
    @edit[:new][item_type][:definition] = Hash.new if @edit[:new][item_type][:definition].nil?
    @edit[:new][item_type][:definition]["content"] ||= Array.new
    temp = Hash.new
    CATEGORY_CHOICES.each do | checkbox_name, checkbox_value |
      if params["check_#{checkbox_name}"]
        if params["check_#{checkbox_name}"] != "null"
          temp["target"] = checkbox_name
        else
          temp["target"] = checkbox_name
          @edit[:new][item_type][:definition]["content"].delete(temp)
          temp = Hash.new
        end
      end
      @edit[:new][item_type][:definition]["content"].push(temp) if !temp.empty? && !@edit[:new][item_type][:definition]["content"].include?(temp)
      temp = Hash.new
    end
  end

  def ap_get_form_vars_file
    unless params[:entry]['fname'].present?
      add_flash(I18n.t("flash.edit.field_required", :field=>"File Entry"), :error)
      return
    end
    item_type = params[:item]['type1']
    @edit[:file_names] = session[:file_names].empty? ? [] : session[:file_names].dup
    unless @edit[:file_names].nil?
      @edit[:file_names].delete_if { |fn| fn['target'] == session[:edit_filename] }

      found = !!@edit[:file_names].find { |fn| fn['target'] == params[:entry]['fname'] }

      if !found && params[:entry]['fname'].present?
        @edit[:file_names].push(
          'target'  => params[:entry]['fname'],
          'content' => !!params[:entry_content]
        )
      end
    end
    session[:file_names] = @edit[:file_names].dup
    @edit[:new][item_type] = {
     :type       => item_type,
     :definition => { "stats" => [] },
    }
    session[:file_names].each do |fname|
      @edit[:new][item_type][:definition]["stats"].push(fname.dup) unless fname.empty?
    end
    session[:edit_filename] = nil
  end

  def ap_get_form_vars_registry
    unless params[:entry]['kname'].present? && params[:entry]['value'].present?
      session[:reg_data] = {
        :key   => params[:entry]['kname'],
        :value => params[:entry]['value'],
      }
      add_flash(I18n.t("flash.edit.field_required", :field=>"Registry Entry"), :error)
      return
    end
    session[:reg_data] = {}

    item_type = params[:item]['type2']
    @edit[:reg_entries] = session[:reg_entries].empty? ? [] : session[:reg_entries].dup

    @edit[:reg_entries].delete_if do |regentry|
      regentry['key'] == session[:reg_data][:key] &&
       regentry['value'] == session[:reg_data][:value]
    end

    found = false
    if params[:entry] && params[:entry][:id]

      entry_index    = params[:entry][:id].to_i
      sorted_entries = session[:reg_entries].sort_by { |r| r['key'] }

      if entry_index < sorted_entries.length
        regentry = sorted_entries[entry_index]
        regentry.update(
          'depth' => 0,
          'hive'  => 'HKLM',
          'value' => params[:entry]['value'],
          'key'   => params[:entry]['kname'],
        )
        found = true
      end
    end

    @edit[:reg_entries].push(
      'depth' => 0,
      'hive'  => 'HKLM',
      'value' => params[:entry]['value'],
      'key'   => params[:entry]['kname'],
    ) unless found

    session[:reg_entries] = @edit[:reg_entries].dup
    @edit[:new][item_type] = {
      :type       => item_type,
      :definition => { 'content' => [] }
    }

    session[:reg_entries].each do |entry|
      @edit[:new][item_type][:definition]['content'].push(entry.dup) unless entry.empty?
    end
  end

  def ap_get_form_vars_event_log
    if params[:entry]["name"] == ""
      session[:nteventlog_data] = Hash.new
      session[:nteventlog_data][:name] = params[:entry]["name"]
      session[:nteventlog_data][:message] = params[:entry]["message"]
      session[:nteventlog_data][:level] = params[:entry]["level"]
      #session[:nteventlog_data][:rec_count] = params[:entry]["rec_count"].to_i
      session[:nteventlog_data][:num_days] = params[:entry]["num_days"].to_i
      session[:nteventlog_data][:source] = params[:entry]["source"]
      add_flash(I18n.t("flash.edit.field_required", :field=>"Event log name"), :error)
      return
    else
      session[:nteventlog_data] = Hash.new
    end
    item_type = params[:item]["type3"]
    @edit[:new][item_type] = Hash.new
    @edit[:nteventlog_entries] = Array.new if @edit[:nteventlog_entries].nil?
    @edit[:nteventlog_entries] = session[:nteventlog_entries].dup if !session[:nteventlog_entries].blank?
    temp = Hash.new
    if !@edit[:nteventlog_entries].nil?
      if params[:item]["id"]
        @edit[:nteventlog_entries].sort_by { |r| r[:name] }.each_with_index do |nteventlog,i|
          if i == params[:item]["id"].to_i
            @edit[:nteventlog_entries][i][:name] = params[:entry]["name"]
            @edit[:nteventlog_entries][i][:filter][:message] = params[:entry]["message"]
            @edit[:nteventlog_entries][i][:filter][:level] = params[:entry]["level"]
            #@edit[:nteventlog_entries][i][:filter][:rec_count] = params[:entry]["rec_count"].to_i
            @edit[:nteventlog_entries][i][:filter][:num_days] = params[:entry]["num_days"].to_i
            @edit[:nteventlog_entries][i][:filter][:source] = params[:entry]["source"]
          end
        end
      else
        temp[:name] = params[:entry]["name"]
        temp[:filter] = Hash.new
        temp[:filter][:message] = params[:entry]["message"]
        temp[:filter][:level] = params[:entry]["level"]
        #temp[:filter][:rec_count] = params[:entry]["rec_count"].to_i
        temp[:filter][:num_days] = params[:entry]["num_days"].to_i
        temp[:filter][:source] = params[:entry]["source"]
        @edit[:nteventlog_entries].push(temp)
      end
    end
    session[:nteventlog_entries] = @edit[:nteventlog_entries].dup
    @edit[:new][item_type][:type] = params[:item]["type3"]
    @edit[:new][item_type][:definition] = Hash.new if @edit[:new][item_type][:definition].nil?
    @edit[:new][item_type][:definition]["content"] = Array.new if @edit[:new][item_type][:definition]["content"].nil?
    session[:nteventlog_entries].each do | fname|
      temp = fname.dup
      @edit[:new][item_type][:definition]["content"].push(temp) if !temp.empty?
    end
  end

  # Get variables from edit form
  def ap_get_form_vars
    @scan = @edit[:scan_id] ? ScanItemSet.find_by_id(@edit[:scan_id]) : ScanItemSet.new
    @edit[:new][:name]        = params[:name]        if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]

    if params[:item].present? || params[:item_type].present?
      ap_get_form_vars_category if @sb[:ap_active_tab] == "category"
      if @edit[:new]["category"]
        @edit[:new]["category"][:name]        = "#{params[:name]}_category"             if params[:name]
        @edit[:new]["category"][:description] = "#{params[:description]} category Scan" if params[:description]
      end

      ap_get_form_vars_file if @sb[:ap_active_tab] == "file" && params[:item] && params[:item]["type1"]
      if @edit[:new]["file"]
        @edit[:new]["file"][:name]        = "#{params[:name]}_file"             if params[:name]
        @edit[:new]["file"][:description] = "#{params[:description]} file Scan" if params[:description]
      end

      ap_get_form_vars_registry if @sb[:ap_active_tab] == "registry"
      if @edit[:new]["registry"]
        @edit[:new]["registry"][:name]        = "#{params[:name]}_registry"             if params[:name]
        @edit[:new]["registry"][:description] = "#{params[:description]} registry Scan" if params[:description]
      end

      ap_get_form_vars_event_log if @sb[:ap_active_tab] == "event_log"
      if @edit[:new]["nteventlog"]
        @edit[:new]["nteventlog"][:name]        = "#{params[:name]}_nteventlog"             if params[:name]
        @edit[:new]["nteventlog"][:description] = "#{params[:description]} nteventlog Scan" if params[:description]
      end
    end
  end

  def ap_build_edit_screen
    @embedded = true            # don't show flash msg or check boxes in analysis profiles partial
    @scan = @edit[:scan_id] ? ScanItemSet.find_by_id(@edit[:scan_id]) : ScanItemSet.new
    @sb[:req] = "new" if ["new", "copy", "create"].include?(request.parameters["action"]) || ["copy", "Host", "Vm"].include?(params[:typ])
    @sb[:req] = "edit" if ["edit", "update"].include?(request.parameters["action"]) || params[:typ] == "edit"
    @scan.members.each do | a |
      case a.item_type
      when "category"
        @category = Array.new if @category.nil?
        @category.push(a)
      when "file"
        @file = Array.new if @file.nil?
        @file.push(a)
      when "registry"
        @registry = Array.new if @registry.nil?
        @registry.push(a)
      when "nteventlog"
        @nteventlog = Array.new if @nteventlog.nil?
        @nteventlog.push(a)
      end
    end
    #@sb[:miq_id] = params[:id] if params[:id]
    session[:reg_data] = Hash.new if params[:entry].nil?
    session[:nteventlog_data] = Hash.new if params[:entry].nil?
    session[:edit_filename] = Array.new
    @in_a_form = true
  end

  # Delete all selected or single displayed scanitemset(s)
  def ap_deletescanitems(scanitems)
    ap_process_scanitems(scanitems, "destroy")
  end

  # Common scanitemset Set button handler routines follow
  def ap_process_scanitems(scanitems, task)
    process_elements(scanitems, ScanItem, task)
  end

  # Common scanitemset button handler routines follow
  def ap_process_scanitemsets(scanitemsets, task)
    process_elements(scanitemsets, ScanItemSet, task)
  end

end
