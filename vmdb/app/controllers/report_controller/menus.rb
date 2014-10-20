module ReportController::Menus
  extend ActiveSupport::Concern

  def get_tree_data
    # build tree for selected role in left div of the right cell
    session[:role_choice]   = MiqGroup.find(from_cid(x_node(:roles_tree).split('-').last)).description if !x_node(:roles_tree).split('-').last.blank?
    session[:node_selected] = "" if params[:action] != "menu_field_changed"
    @sb[:menu_default] = false
    if @changed || @menu_lastaction == "discard_changes"
      @temp[:rpt_menu] = copy_array(@edit[:new])
    elsif @menu_lastaction == "default"
    else
      build_report_listnav("reports","menu")
    end
    @menu_lastaction     = "menu_editor" if @menu_lastaction != "commit" && @menu_lastaction != "discard_changes" && params[:action] == "get_tree_data"
    menu_editor
  end

  def menu_editor
    menu_set_form_vars if ["explorer","tree_select","x_history"].include?(params[:action])
    @in_a_form = true
    if @menu_lastaction != "menu_editor"
      @temp[:menu_roles_tree] = build_menu_tree(@edit[:new])
    else
      @temp[:menu_roles_tree] = build_menu_tree(@temp[:rpt_menu]) # changing rpt_menu if changes have been commited to show updated tree with changes
    end
    @sb[:role_list_flag] = true if params[:id]

    if params[:node_id]
      session[:node_selected] = params[:node_id]
    else
      session[:node_selected] = "b__Report Menus for #{session[:role_choice]}" if session[:node_selected].blank? || session[:node_selected] == ""
    end
    @sb[:node_clicked] = (params[:node_clicked] == "1")

    @breadcrumbs = Array.new
    drop_breadcrumb( {:name=>"Edit Report menus for '#{session[:role_choice]}'"} )
    @lock_tree = true
    if session[:node_selected].index(':').nil? || params[:button] == "reset"
      edit_folder
      replace_right_cell if params[:node_clicked]
    else
      edit_reports
    end
  end

  def menu_folder_message_display
    params[:typ] == "delete" ?
      add_flash(_("Can not delete folder, one or more reports in the selected folder are not owned by your group"),:warning) :
      add_flash(_("Double Click on 'New Folder' to edit"), :warning)
    render :update do |page|                    # Use JS to update the display
      page.replace("flash_msg_div_menu_list", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"_menu_list"})
    end
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def menu_field_changed
    return unless load_edit("menu_edit__#{session[:role_choice] ? session[:role_choice] : "new"}","replace_cell__explorer")
    menu_get_form_vars
    @in_a_form = true
    @edit[:tree_arr]  = Array.new
    @edit[:tree_hash] = Hash.new
    @edit[:temp_new]  = Array.new

    if params[:tree]
      @menu_lastaction = "commit"
      doc = MiqXml.load(params[:tree].gsub(/&/n, '&amp;'))
      doc.root.each_element("row") do |r|
        r.each_element("cell") do |c|
          if c.text.nil?
            @sb[:tree_err] = true
            add_flash(_("%s is required") % "Folder name", :error)
          elsif @edit[:tree_arr].include?(c.text)
            @sb[:tree_err] = true
            add_flash(_("%{field} '%{value}' is already in use") % {:field=>"Folder name", :value=>c.text}, :error)
          else
            @sb[:tree_err] = false
            @edit[:tree_arr].push(c.text)
            @edit[:tree_hash][r.attributes['id'].split('_')[1]] = c.text
          end
        end
      end

      @edit[:temp_new] = Array.new
      if @edit[:tree_arr].blank?
        #if all subfolders were deleted
        @edit[:temp_new].push(@edit[:temp_arr][0],"")
      else
        @edit[:tree_arr].each do |el|
          old_folder = @edit[:tree_hash].key(el)
          @edit[:temp_arr].each do |arr|
            arr = arr.to_miq_a
            temp = Array.new
            if session[:node_selected].split('__')[1] == "Report Menus for #{session[:role_choice]}"
              if arr[0] == old_folder
                temp.push(el)
                temp.push(arr[1])
              elsif old_folder.nil?
                temp.push(el) if !temp.include?(el)
                temp.push([]) if !temp.include?([])
              end
              @edit[:temp_new].push(temp) if !temp.empty? && !@edit[:temp_new].include?(temp)
            else
              @edit[:temp_new][0] = @edit[:temp_arr][0]
              arr.each do |a|
                if a[0] == old_folder
                  temp.push(el)
                  temp.push(a[1])
                elsif old_folder.nil?
                  temp.push(el) if !temp.include?(el)
                  temp.push([]) if !temp.include?([])
                end
                @edit[:temp_new][1] = Array.new if @edit[:temp_new][1].nil?
                @edit[:temp_new][1].push(temp) if !temp.empty? && !@edit[:temp_new][1].include?(temp)
              end
            end
          end
        end
      end

      if !@edit[:idx].nil?
        @edit[:new][@edit[:idx]] = copy_array(@edit[:temp_new])
      else
        @edit[:new] = copy_array(@edit[:temp_new])
      end
    end

    if params[:pressed] == "commit" && (@edit[:selected_reports] || @edit[:available_reports])
      @menu_lastaction = "commit"
      val              = session[:node_selected].split('__')[1]
      old_val          = val.split(':')
      idx              = @edit[:new].index(@edit[:temp_arr])            # index of temp_array that being worked on, in set_data
      idx2             = @edit[:temp_arr].index(old_val[0])             # index of parent folder in temp_array
      if !@edit[:user_typ]
        #remove * at the starting of report names, before saving them for user
        @edit[:selected_reports].each_with_index do |rep,i|
          @edit[:selected_reports][i] = rep[1..rep.length-1].strip! if rep.starts_with?('* ')
        end
      end
      @edit[:temp_arr].each do |arr|
        if arr.class == Array
          arr.each do |a|
            if a[0] == old_val[1]
              @edit[:temp] = a
              idx3 = @edit[:temp].index(old_val[1])         # index of subfolder in temp that's part of temp_array
              idx4 = @edit[:temp_arr][idx2+1].index(@edit[:temp])       # index of temp in temp_array
              if a[1].nil?
                @edit[:temp].push(@edit[:selected_reports])
              else
                @edit[:reports] = a[1]
                idx5 = @edit[:temp].index(@edit[:reports])        # index of reports array in temp
                @edit[:temp][idx5] = @edit[:selected_reports]
              end
              @edit[:temp_arr][idx2+1][idx4] = @edit[:temp].dup
              @edit[:new][idx] = @edit[:temp_arr].dup
            end
          end
        end
      end
    end

    @edit[:commited_new] = copy_array(@edit[:new])
    id                   = session[:node_selected].split('__')
    @selected            = id[1].split(':')
    @changed             = (@edit[:new] != @edit[:current]) if @menu_lastaction == "commit"
    get_tree_data if (!params[:selected_reports] && !params[:available_reports]) || @menu_lastaction == "commit"
    # load if something in report selection changed or if something was commited
    if !params[:tree]
      replace_right_cell(:menu_edit_action => "menu_commit_reports")
    else
      replace_right_cell(:menu_edit_action => "menu_commit_folders")
    end
  end

  def discard_changes
    @menu_lastaction = "discard_changes"
    id               = session[:node_selected].split('__')
    @selected        = id[1].split(':')
    get_tree_data
    @edit[:new]      = copy_array(@edit[:commited_new]) if @edit[:commited_new]
    @changed         = (@edit[:new] != @edit[:current])
    if params[:pressed] == "discard_reports"
      replace_right_cell(:menu_edit_action => "menu_discard_reports")
    else
      replace_right_cell(:menu_edit_action => "menu_discard_folders")
    end
  end

  def menu_update
    menu_get_form_vars
  # @changed = (@edit[:new] != @edit[:current])
    if params[:button] == "cancel"
      add_flash(_("Edit of %{model} for role \"%{role}\" was cancelled by the user") % {:model=>"Report Menu", :role=>session[:role_choice]})
      session[:node_selected]   = ""
      session[:role_choice]     = nil
      @new_menu_node            = "roleroot"
      @temp[:menu_roles_tree] = nil
      @lock_tree                = false
      @edit = session[:edit]    = nil
      @changed                  = session[:changed] = false
      self.x_node = "root"
      replace_right_cell
    elsif params[:button] == "reset"
      @changed                   = session[:changed] = false
      @edit[:new]                = copy_array(@edit[:current])
      @menu_lastaction           = "reset"
      add_flash(_("All changes have been reset"), :warning)
      get_tree_data
      replace_right_cell(:menu_edit_action => "menu_reset")
    elsif params[:button] == "default"
      @temp[:menu_roles_tree] = build_report_listnav("reports","menu","default")
      @edit[:new]               = copy_array(@temp[:rpt_menu])
      @menu_lastaction          = "default"
      add_flash(_("%s set to default") % "Report Menu", :warning)
      get_tree_data
      #set menu_default flag to true
      @sb[:menu_default] = true
      @sb[:rep_tree_build_time] = Time.now.utc
      replace_right_cell(:menu_edit_action => "menu_default")
    elsif params[:button] == "save"
      @menu_lastaction = "save"
      role             = session[:role_choice] unless session[:role_choice].nil?
      rec              = MiqGroup.find_by_description(role)
      rec.settings ||= Hash.new
      if @sb[:menu_default]
        #delete report_menus from settings if menu set to default
        rec.settings.delete(:report_menus)
      else
        rec.settings[:report_menus] ||= Hash.new
        rec.settings[:report_menus]  = copy_array(@edit[:new])
      end

      if rec.save
        session[:edit] = nil  # clean out the saved info
        add_flash(_("%{model} for role \"%{role}\" was saved") % {:model=>"Report Menu", :role=>session[:role_choice]})
        get_tree_data
        session[:node_selected]   = ""
        session[:role_choice]     = nil
        @new_menu_node            = "roleroot"
        @temp[:menu_roles_tree] = nil
        @lock_tree                = false
        @changed                  = session[:changed] = false
        @edit = session[:edit]    = nil
        self.x_node = "root"
        @in_a_form = false
        replace_right_cell(:replace_trees => [:reports])
      else
        rec.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @in_a_form              = true
        session[:changed]       = @changed
        @changed                = true
      end
    end
  end

  private

  def edit_reports
    @edit[:selected_reports] = Array.new
    @edit[:available_reports] = Array.new
    user = User.find_by_userid(session[:userid])
    id = session[:node_selected].split('__')
    @selected = id[1].split(':')
    all = MiqReport.all.sort{|a,b| a.rpt_type + a.filename.to_s + a.name <=> b.rpt_type  + b.filename.to_s + b.name}
    @all_reports = Array.new
    all.each do |r|
      next if r.template_type != "report" && ! r.template_type.blank?
      @all_reports.push(r.name)
    end

    @selected_reports = Array.new
    @available_reports = Array.new
    @assigned_reports = Array.new

    #calculating selected reports for selected folder
    @edit[:new].each do |arr|
      if arr[0] == @selected[0]
      if arr.class == Array
        arr.each do |a|
          if a.class == Array
            a.each do |r|
              if r[0] == @selected[1]
                r.each do |rep|
                  if rep.class == Array
                    rep.each do |r|
                      report = MiqReport.find_by_name(r.strip)
                      r_name = (@edit[:user_typ] || report.miq_group_id.to_i == user.current_group.id.to_i) ? r : "* #{r}"
                      @selected_reports.push(r_name)
                    end
                  end
                end
              end
            end
          end
        end
      end
      end
    end

    #Calculating reports that are asigned to any of the folders
    @edit[:new].each do |arr|
      if arr.class == Array
        arr.each do |a|
          if a.class == Array
            a.each do |r|
              r.each do |rep|
                if rep.class == Array
                  rep.each do |r|
                    @assigned_reports.push(r)
                  end
                end
              end
            end
          end
        end
      end
    end

    @all_reports.each do |rep|
      if !@assigned_reports.include?(rep)
        r = MiqReport.find_by_name(rep.strip)
        @available_reports.push(rep) if @edit[:user_typ] || r.miq_group_id.to_i == user.current_group.id.to_i
      end
    end

    @edit[:old_selected_reports] = @selected_reports.dup
    @edit[:old_available_reports] = @available_reports.dup
    @edit[:selected_reports] = @selected_reports.dup
    @edit[:available_reports] = @available_reports.dup

    # reload grid if folder node was clicked for report management
    #if params[:action] == "menu_editor" && @menu_lastaction != "commit" && @menu_lastaction != "discard_changes"
    if params[:pressed] != "commit" && params[:pressed] != "discard_reports" && params[:button] != "default" && params[:action] != "menu_field_changed"
      replace_right_cell(:menu_edit_action => "menu_edit_reports")
    end
  end

  #menus tree for the group selected in the roles tree on left
  def build_menu_tree(rpt_menu,tree_type="reports")
    @temp[:rpt_menu] = Array.new
    @temp[:menu_roles_tree] = nil
    menus = Array.new
    rpt_menu.each do |r|
      # create/modify new array that doesn't have custom reports folder, dont need custom folder in menu_editor
      # add any new empty folders that were added
      menus.push(r) if (r[1] && r[1].empty?) || (r[1] && !r[1].empty? && r[1][0].empty?) || (r[1] && !r[1].empty? && !r[1][0].empty? && r[1][0][0] != "Custom") # Check the second level menu for "Custom"
    end
    @tree_type = "menu"
    @temp[:rpt_menu] = menus
    base_node = {
        :key    => "b__Report Menus for #{session[:role_choice]}", # Added divider '|' in case DHTMLX adds something
        :title  => 'Top Level',
        :icon   => 'folder.png',
        :expand => true,
        :style  => 'background: #fff;
                    padding: 2px 0 6px 2px;
                    color:#4b4b4b;
                    font-size:12px;
                    font-weight:bold;'
    }

    @tree = Array.new
    @branch = Array.new
    @parent_node = Hash.new
    menus.each do |r|
      r.each_slice(2) do |menu,section|
        @parent_node = {
          :key     => "p__#{menu}",
          :title   => menu,
          :tooltip => "Group: #{menu}",
          :icon    => 'folder.png',
          :style   => 'cursor:default;
                       color:#4b4b4b;
                       display: block;
                       font-size:1.1em bold;
                       font-weight:bold;
                       height:22px;
                       line-height: 22px;
                       text-decoration:none;
                       text-indent: 8px;
                       vertical-align: top;
                       width: 205px;'
        }
        if !section.nil? && section.class != String
          section.each do |s|
            if s.class == Array
              s.each do |rec|
                @branch_node = Array.new
                if rec.class == String
                  @menu_node = {
                      :key     => "s__#{menu}:#{rec}",
                      :title   => rec,
                      :tooltip => "Menu: #{rec}",
                      :style   => 'cursor:default;', # No cursor pointer
                      :icon    => 'folder.png'
                  }
                else
                  rec.each do |r|
                    temp = rep_kids_menutree(r)
                    @branch_node.push(temp) unless temp.nil? || temp.empty?
                  end
                  @menu_node[:children] = @branch_node unless @branch_node.nil? || @menu_node.include?(@branch_node)
                end
                @branch.push(@menu_node) unless @menu_node.nil? || @branch.include?(@menu_node)
              end
            elsif s.class == String
              temp = rep_kids_menutree(s)
              @branch.push(temp) unless temp.nil? || temp.empty?
            end
          end
        end
        @parent_node[:children] = @branch unless @branch.nil? || @parent_node.include?(@branch)
        @tree.push(@parent_node) unless @parent_node.nil?
        @branch = Array.new
      end
    end
    base_node[:children] = @tree
    menu_roles_tree = base_node.to_json unless base_node.nil? || base_node.empty?
    return menu_roles_tree
  end

  def rep_kids_menutree(rec)
    rpt = MiqReport.find_by_name(rec.strip)
    @tag_node = Hash.new
    if !rpt.nil?
      @tag_node[:key]     = "r__#{rpt.id}_#{rpt.name}"
      @tag_node[:title]   = rpt.name
      @tag_node[:tooltip] =  "Report: " + rpt.name
      @tag_node[:icon]    = "report.png"
      @tag_node[:style]   = "padding-bottom: 2px; padding-left: 0px;" # No cursor pointer
    end
    return @tag_node
  end

  def move_menu_cols_left
    if params[:available_reports].nil? || params[:available_reports].length == 0 || params[:available_reports][0] == ""
      add_flash(_("No %s were selected to move left") % "fields", :error)
    else
      @edit[:available_reports].each do |af|                  # Go thru all available columns
        if params[:available_reports].include?(af)            # See if this column was selected to move
          @edit[:selected_reports].push(af)                   # Add it to the new fields list
        end
      end
      @edit[:available_reports].delete_if{|af| params[:available_reports].include?(af)} # Remove selected fields
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
  end

  def move_menu_cols_right
    if params[:selected_reports].nil? || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No %s were selected to move right") % "fields", :error)
      return
    else
      user = User.find_by_userid(session[:userid])
      flg = 0
      @edit[:selected_reports].each do |nf|               # Go thru all new fields
        if params[:selected_reports].include?(nf)         # See if this col was selected to move
          field = nf.split('* ')
          r = MiqReport.find_by_name(field.length == 1 ? field[0].strip : field[1].strip)
          if !user.admin_user? && r.miq_group_id.to_i != user.current_group.id.to_i && flg == 0
            flg = 1
            #only show this flash message once for all reports
            add_flash(_("One or more selected reports are not owned by your group, they cannot be moved", :field=>"fields"), :warning)
          end
          if user.admin_user? || r.miq_group_id.to_i == user.current_group.id.to_i
            @edit[:available_reports].push(nf) if @edit[:user_typ] || r.miq_group_id.to_i == user.current_group.id.to_i             # Add to the available fields list
            @edit[:selected_reports].delete(nf)
          end
        end
      end
      #@edit[:selected_reports].delete_if{|nf| params[:selected_reports].include?(nf)} # Remove selected fields
      @edit[:available_reports].sort!                 # Sort the available fields array
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
  end

  def move_menu_cols_up
    if !params[:selected_reports] || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No %s were selected to move up") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move up") % "fields", :error)
    else
      if first_idx > 0
        @edit[:selected_reports][first_idx..last_idx].reverse.each do |field|
          pulled = @edit[:selected_reports].delete(field)
          @edit[:selected_reports].insert(first_idx - 1, pulled)
        end
      end
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
    @selected_reps = params[:selected_reports]
  end

  def move_menu_cols_down
    if !params[:selected_reports] || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No %s were selected to move down") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move down") % "fields", :error)
    else
      if last_idx < @edit[:selected_reports].length - 1
        insert_idx = last_idx + 1   # Insert before the element after the last one
        insert_idx = -1 if last_idx == @edit[:selected_reports].length - 2 # Insert at end if 1 away from end
        @edit[:selected_reports][first_idx..last_idx].each do |field|
          pulled = @edit[:selected_reports].delete(field)
          @edit[:selected_reports].insert(insert_idx, pulled)
        end
      end
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
    @selected_reps = params[:selected_reports]
  end

  def move_menu_cols_top
    if !params[:selected_reports] || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No %s were selected to move up") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move up") % "fields", :error)
    else
      if first_idx > 0
        @edit[:selected_reports][first_idx..last_idx].reverse.each do |field|
          pulled = @edit[:selected_reports].delete(field)
          @edit[:selected_reports].unshift(pulled)
        end
      end
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
    @selected_reps = params[:selected_reports]
  end

  def move_menu_cols_bottom
    if !params[:selected_reports] || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No %s were selected to move down") % "fields", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move down") % "fields", :error)
    else
      if last_idx < @edit[:selected_reports].length - 1
        @edit[:selected_reports][first_idx..last_idx].each do |field|
          pulled = @edit[:selected_reports].delete(field)
          @edit[:selected_reports].push(pulled)
        end
      end
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
    @selected_reps = params[:selected_reports]
  end

  def selected_menu_consecutive?
    first_idx = last_idx = 0
    @edit[:selected_reports].each_with_index do |nf,idx|
      first_idx = idx if nf == params[:selected_reports].first
      if nf == params[:selected_reports].last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > params[:selected_reports].length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  def menu_get_form_vars
    @edit[:form_vars][:selected_reports] = params[:selected_reports] if params[:selected_reports]
    @edit[:form_vars][:available_reports] = params[:available_reports] if params[:available_reports]
    @edit[:temp_arr] = Array.new
    id = session[:node_selected].split('__')
    selected = id[1].split(':')
    @edit[:new].each do |a1,a2|
      if a1 == selected[0]
        @edit[:temp_arr].push(a1)
        @edit[:temp_arr].push(a2)
      elsif selected[0] == "Report Menus for #{session[:role_choice]}"
        @edit[:temp_arr] = copy_array(@edit[:new])
      end
      @edit[:idx] = @edit[:new].index(@edit[:temp_arr])
    end

    if params[:button]
      move_menu_cols_right if params[:button] == "right"
      move_menu_cols_left if params[:button] == "left"
      move_menu_cols_up if params[:button] == "up"
      move_menu_cols_down if params[:button] == "down"
      move_menu_cols_top if params[:button] == "top"
      move_menu_cols_bottom if params[:button] == "bottom"
    end
  end

  def menu_set_form_vars
    #session[:changed] = @changed = false
    @edit = Hash.new
    @edit[:new] = Array.new
    @edit[:key] = "menu_edit__#{session[:role_choice] ? session[:role_choice] : "new"}"

    @edit[:temp_arr] = Array.new
    @edit[:form_vars] = Hash.new
    @edit[:current] = Array.new
    @edit[:new] = @temp[:rpt_menu] if !@temp[:rpt_menu].nil?
    user = User.find_by_userid(session[:userid])
    @edit[:user_typ] = user.admin_user?
    @edit[:user_group] = user.current_group.id
    @edit[:group_reports] = Array.new
    menu_set_reports_for_group
    @edit[:current] = copy_hash(@edit[:new]) if !@edit[:new].nil?
    session[:edit] = @edit
  end

  def menu_set_reports_for_group
    @edit[:new].each do |r|
      r.each_slice(2) do |menu,section|
      title = "#{menu}/"
        if !section.nil? && section.class != String
          section.each do |s|
            if s.class == Array
              s.each do |rec|
                if rec.class == String
                  @sub_title = title + "#{rec}/"
                else
                  rec.each do |r|
                    rpt = MiqReport.find_by_name(r.strip)
                    @edit[:group_reports].push(@sub_title + r) if rpt && rpt.miq_group && rpt.miq_group.id.to_i == @edit[:user_group].to_i
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Render the view data to xml for the grid view
  def menu_to_xml(view, header)
    xml = MiqXml.createDoc(nil)
    # Create root element
    root = xml.add_element("rows")
    # Added header properties
    head = root.add_element("head")
    new_column = head.add_element("column", {"width"=>"200", "align"=>"left", "sort"=>"na"})
    new_column.add_attribute("type", 'edtxt')
    new_column.text = header.gsub(/&/n, '&amp;') if !header.blank?
    view.each_with_index do |row,i|
      if row      #don't add if row came in a nil
        if @edit[:user_typ]
          # if user is admin/super admin, no need to add special characters in id
          new_row = root.add_element("row", {"id"=>"i_#{row.gsub(/&/n, '&amp;')}"})
          new_row.add_element("cell",{"align"=>"left"}).text = row  # Checkbox column unchecked
        else
          if @edit[:group_reports].empty?
            # if group does not own any reports then add special characters in id, they cannot delete any folders.
            new_row = root.add_element("row", {"id"=>"__|i_#{row.gsub(/&/n, '&amp;')}"})
            new_row.add_element("cell",{"align"=>"left"}).text = row  # Checkbox column unchecked
          else
            prefix = "|-|"
            @edit[:group_reports].each do |rep|
              #need to check if report is not owned by user add special character to the row id so it can be tracked in JS and folder cannnot be deleted in menu editor
              nodes = rep.split('/')
              val = session[:node_selected].split('__')[0]
              if val == "b"
                # if top node
                if nodes[0] == row
                  #if report belongs to group
                  @row_id = "i_#{row.gsub(/&/n, '&amp;')}"
                  #break
                else
                  #if report is owned by other group
                  @row_id = "#{prefix}i_#{row.gsub(/&/n, '&amp;')}"
                end
              else
                #if second level folder node
                if nodes[1] == row
                  #if report belongs to group
                  @row_id = "i_#{row.gsub(/&/n, '&amp;')}"
                  #break
                else
                  #if report is owned by other group
                  @row_id = "#{prefix}i_#{row.gsub(/&/n, '&amp;')}"
                end
              end
            end
            new_row = root.add_element("row", {"id"=>@row_id})
            new_row.add_element("cell",{"align"=>"left"}).text = row  # Checkbox column unchecked
          end
        end
      end
    end
    return xml.to_s
  end

  def edit_folder
    session[:node_selected] = "b__Report Menus for #{session[:role_choice]}" if params[:button] == "reset" || params[:button] == "default"  # resetting node in case reset button is pressed
    @selected = session[:node_selected].split('__')
    @folders = Array.new
    @edit[:folders] = Array.new

    #calculating selected reports for selected folder
    if session[:node_selected] == "b__Report Menus for #{session[:role_choice]}"
      @edit[:new].each do |arr|
        if arr[0] != @sb[:grp_title]
          @folders.push(arr[0])
        end
      end
    else
      @edit[:new].each do |arr|
        if arr[0] == @selected[1]
          if arr.class == Array
            arr.each do |a|
              if a.class == Array
                a.each do |s|
                  @folders.push(s[0])
                end
              end
            end
          end
        end
      end
    end
    @edit[:folders] = @folders.dup
    @temp[:grid_xml] = menu_to_xml(@edit[:folders],@selected[1])
  end

  def menu_get_all
    roles,title = get_group_roles
    @sb[:menu] = Hash.new
    roles.sort_by { |a| a.name.downcase }.each do |r|
      @sb[:menu][r.id] = r.name
    end
    @right_cell_text = title == "My #{ui_lookup(:model=>"MiqGroup")}" ?
      _("%s") % title :
      _("All %s") % ui_lookup(:models=>"MiqGroup")
    @right_cell_div = "role_list"
    @temp[:menu_roles_tree] = nil
  end

  def get_menu(nodeid)
    # build menu for selected role
    get_tree_data
    @right_cell_div  = "role_list"
    @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name=>session[:role_choice], :model=>ui_lookup(:model=>"MiqGroup")}
  end

  #Build the main roles/menu editor tree
  def build_roles_tree(type, name)
    x_tree_init(name, type, "MiqUserRole", :open_all => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    user = User.find_by_userid(session[:userid])
    if user.super_admin_user?
      title  = "All #{ui_lookup(:models=>"MiqGroup")}"
    else
      title  = "My #{ui_lookup(:model=>"MiqGroup")}"
    end
    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = title
    root[:tooltip] = title
    root[:icon]    = "miq_group.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name)         # Set active node to root if not set
  end

  def get_group_roles
    user = User.find_by_userid(session[:userid])
    if user.super_admin_user?
      roles = MiqGroup.all
      title  = "All #{ui_lookup(:models=>"MiqGroup")}"
    else
      title  = "My #{ui_lookup(:model=>"MiqGroup")}"
      roles = [MiqGroup.find_by_id(user.current_group_id)]
    end
    return roles,title
  end

end
