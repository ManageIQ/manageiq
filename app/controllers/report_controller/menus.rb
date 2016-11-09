module ReportController::Menus
  extend ActiveSupport::Concern

  def get_tree_data
    # build tree for selected role in left div of the right cell
    session[:role_choice]   = MiqGroup.find(from_cid(x_node(:roles_tree).split('-').last)).description unless x_node(:roles_tree).split('-').last.blank?
    session[:node_selected] = "" if params[:action] != "menu_field_changed"
    @sb[:menu_default] = false
    if @changed || @menu_lastaction == "discard_changes"
      @rpt_menu = copy_array(@edit[:new])
    elsif @menu_lastaction == "default"
    else
      build_report_listnav("reports", "menu")
    end
    @menu_lastaction     = "menu_editor" if @menu_lastaction != "commit" && @menu_lastaction != "discard_changes" && params[:action] == "get_tree_data"
    menu_editor
  end

  def menu_editor
    menu_set_form_vars if ["explorer", "tree_select", "x_history"].include?(params[:action])
    @in_a_form = true
    if @menu_lastaction != "menu_editor"
      @menu_roles_tree = TreeBuilderMenuRoles.new("menu_roles_tree", "menu_roles", @sb, session[:role_choice], @edit[:new])
    else
      # changing rpt_menu if changes have been commited to show updated tree with changes
      @menu_roles_tree = TreeBuilderMenuRoles.new("menu_roles_tree", "menu_roles", @sb, session[:role_choice])
    end
    @sb[:role_list_flag] = true if params[:id]

    if params[:node_id]
      session[:node_selected] = params[:node_id]
    elsif session[:node_selected].blank?
      session[:node_selected] = "xx-b__Report Menus for #{session[:role_choice]}"
    end
    @sb[:node_clicked] = (params[:node_clicked] == "1")

    @breadcrumbs = []
    drop_breadcrumb(:name => "Edit Report menus for '#{session[:role_choice]}'")
    @lock_tree = true
    if session[:node_selected].index(':').nil? || params[:button] == "reset"
      edit_folder
      replace_right_cell if params[:node_clicked]
    else
      edit_reports
    end
  end

  def menu_folder_message_display
    text = if params[:typ] == "delete"
             _("Can not delete folder, one or more reports in the selected folder are not owned by your group")
           else
             _("Double Click on 'New Folder' to edit")
           end
    render_flash(text, :warning)
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def menu_field_changed
    return unless load_edit("menu_edit__#{session[:role_choice] ? session[:role_choice] : "new"}", "replace_cell__explorer")
    menu_get_form_vars
    @in_a_form = true
    @edit[:tree_arr]  = []
    @edit[:tree_hash] = {}
    @edit[:temp_new]  = []

    if params[:tree]
      @menu_lastaction = "commit"
      @sb[:tree_err] = false

      rows = JSON.parse(params[:tree], :symbolize_names => true)
      rows.each do |row|
        if row[:text].nil?
          @sb[:tree_err] = true
          add_flash(_("Folder name is required"), :error)
        elsif @edit[:tree_arr].include?(row[:text])
          @sb[:tree_err] = true
          add_flash(_("Folder name '%{value}' is already in use") % {:value => row[:text]}, :error)
        else
          @edit[:tree_arr].push(row[:text])
          @edit[:tree_hash][row[:id].split('_')[1]] = row[:text]
        end
      end

      @edit[:temp_new] = []
      if @edit[:tree_arr].blank?
        # if all subfolders were deleted
        @edit[:temp_new].push(@edit[:temp_arr][0], "")
      else
        @edit[:tree_arr].each do |el|
          old_folder = @edit[:tree_hash].key(el)
          @edit[:temp_arr].each do |arr|
            arr = arr.to_miq_a
            temp = []
            if session[:node_selected].split('__')[1] == "Report Menus for #{session[:role_choice]}"
              if arr[0] == old_folder
                temp.push(el)
                temp.push(arr[1])
              elsif old_folder.nil?
                temp.push(el) unless temp.include?(el)
                temp.push([]) unless temp.include?([])
              end
              @edit[:temp_new].push(temp) if !temp.empty? && !@edit[:temp_new].include?(temp)
            else
              @edit[:temp_new][0] = @edit[:temp_arr][0]
              arr.each do |a|
                if a[0] == old_folder
                  temp.push(el)
                  temp.push(a[1])
                elsif old_folder.nil?
                  temp.push(el) unless temp.include?(el)
                  temp.push([]) unless temp.include?([])
                end
                @edit[:temp_new][1] = [] if @edit[:temp_new][1].nil?
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
      unless @edit[:user_typ]
        # remove * at the starting of report names, before saving them for user
        @edit[:selected_reports].each_with_index do |rep, i|
          @edit[:selected_reports][i] = rep[1..rep.length - 1].strip! if rep.starts_with?('* ')
        end
      end
      @edit[:temp_arr].each do |arr|
        if arr.class == Array
          arr.each do |a|
            if a[0] == old_val[1]
              @edit[:temp] = a
              idx3 = @edit[:temp].index(old_val[1])         # index of subfolder in temp that's part of temp_array
              idx4 = @edit[:temp_arr][idx2 + 1].index(@edit[:temp])       # index of temp in temp_array
              if a[1].nil?
                @edit[:temp].push(@edit[:selected_reports])
              else
                @edit[:reports] = a[1]
                idx5 = @edit[:temp].index(@edit[:reports])        # index of reports array in temp
                @edit[:temp][idx5] = @edit[:selected_reports]
              end
              @edit[:temp_arr][idx2 + 1][idx4] = @edit[:temp].dup
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
      add_flash(_("Edit of Report Menu for role \"%{role}\" was cancelled by the user") %
                  {:role => session[:role_choice]})
      session[:node_selected]   = ""
      session[:role_choice]     = nil
      @new_menu_node            = "roleroot"
      @menu_roles_tree = nil
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
      @menu_roles_tree = TreeBuilder.convert_bs_tree(build_report_listnav("reports", "menu", "default")).to_json
      @edit[:new]               = copy_array(@rpt_menu)
      @menu_lastaction          = "default"
      add_flash(_("Report Menu set to default"), :warning)
      get_tree_data
      # set menu_default flag to true
      @sb[:menu_default] = true
      replace_right_cell(:menu_edit_action => "menu_default")
    elsif params[:button] == "save"
      @menu_lastaction = "save"
      role             = session[:role_choice] unless session[:role_choice].nil?
      rec              = MiqGroup.find_by_description(role)
      rec.settings ||= {}
      if @sb[:menu_default]
        # delete report_menus from settings if menu set to default
        rec.settings.delete(:report_menus)
      else
        rec.settings[:report_menus] ||= {}
        rec.settings[:report_menus]  = copy_array(@edit[:new])
      end

      if rec.save
        session[:edit] = nil  # clean out the saved info
        add_flash(_("Report Menu for role \"%{role}\" was saved") % {:role => session[:role_choice]})
        get_tree_data
        session[:node_selected]   = ""
        session[:role_choice]     = nil
        @new_menu_node            = "roleroot"
        @menu_roles_tree = nil
        @lock_tree                = false
        @changed                  = session[:changed] = false
        @edit = session[:edit]    = nil
        self.x_node = "root"
        @in_a_form = false
        replace_right_cell(:replace_trees => [:reports])
      else
        rec.errors.each do |field, msg|
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
    @edit[:selected_reports] = []
    @edit[:available_reports] = []
    current_group_id = current_user.current_group.try(:id).to_i
    id = session[:node_selected].split('__')
    @selected = id[1].split(':')
    all = MiqReport.all.sort_by { |r| [r.rpt_type, r.filename.to_s, r.name] }
    @all_reports = []
    all.each do |r|
      next if r.template_type != "report" && !r.template_type.blank?
      @all_reports.push(r.name)
    end

    @selected_reports = []
    @available_reports = []
    @assigned_reports = []

    # calculating selected reports for selected folder
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
                        r_name = (@edit[:user_typ] || report.miq_group_id.to_i == current_group_id) ? r : "* #{r}"
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

    # Calculating reports that are asigned to any of the folders
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
      unless @assigned_reports.include?(rep)
        r = MiqReport.find_by_name(rep.strip)
        @available_reports.push(rep) if @edit[:user_typ] || r.miq_group_id.to_i == current_group_id
      end
    end

    @edit[:old_selected_reports] = @selected_reports.dup
    @edit[:old_available_reports] = @available_reports.dup
    @edit[:selected_reports] = @selected_reports.dup
    @edit[:available_reports] = @available_reports.dup

    # reload grid if folder node was clicked for report management
    # if params[:action] == "menu_editor" && @menu_lastaction != "commit" && @menu_lastaction != "discard_changes"
    if params[:pressed] != "commit" && params[:pressed] != "discard_reports" && params[:button] != "default" && params[:action] != "menu_field_changed"
      replace_right_cell(:menu_edit_action => "menu_edit_reports")
    end
  end

  # Builds menu for left column of right cell
  # This has been largely replaced by TreeBuilderMenuRoles class,
  # but is still called from ApplicationController.
  #
  def build_menu_tree(rpt_menu, _tree_type = "reports")
    # rpt_menu is already part of @sb, and passed to TreeBuilderMenuRoles through it.
    tree = TreeBuilderMenuRoles.new("menu_roles_tree", "menu_roles", @sb, session[:role_choice])
    @rpt_menu = tree.rpt_menu

    tree.hash_tree
  end

  def move_menu_cols_left
    if params[:available_reports].nil? || params[:available_reports].length == 0 || params[:available_reports][0] == ""
      add_flash(_("No fields were selected to move left"), :error)
    else
      @edit[:available_reports].each do |af|                  # Go thru all available columns
        if params[:available_reports].include?(af)            # See if this column was selected to move
          @edit[:selected_reports].push(af)                   # Add it to the new fields list
        end
      end
      @edit[:available_reports].delete_if { |af| params[:available_reports].include?(af) } # Remove selected fields
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
  end

  def move_menu_cols_right
    if params[:selected_reports].nil? || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No fields were selected to move right"), :error)
      return
    else
      user = current_user
      flg = 0
      @edit[:selected_reports].each do |nf|               # Go thru all new fields
        if params[:selected_reports].include?(nf)         # See if this col was selected to move
          field = nf.split('* ')
          r = MiqReport.find_by_name(field.length == 1 ? field[0].strip : field[1].strip)
          if !user.admin_user? && r.miq_group_id.to_i != user.current_group.id.to_i && flg == 0
            flg = 1
            # only show this flash message once for all reports
            add_flash(_("One or more selected reports are not owned by your group, they cannot be moved"), :warning)
          end
          if user.admin_user? || r.miq_group_id.to_i == user.current_group.id.to_i
            @edit[:available_reports].push(nf) if @edit[:user_typ] || r.miq_group_id.to_i == user.current_group.id.to_i             # Add to the available fields list
            @edit[:selected_reports].delete(nf)
          end
        end
      end
      # @edit[:selected_reports].delete_if{|nf| params[:selected_reports].include?(nf)} # Remove selected fields
      @edit[:available_reports].sort!                 # Sort the available fields array
      @refresh_div = "menu_div2"
      @refresh_partial = "/report/menu_form2"
    end
  end

  def move_menu_cols_up
    if !params[:selected_reports] || params[:selected_reports].length == 0 || params[:selected_reports][0] == ""
      add_flash(_("No fields were selected to move up"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move up"), :error)
    else
      if first_idx > 0
        @edit[:selected_reports][first_idx..last_idx].reverse_each do |field|
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
      add_flash(_("No fields were selected to move down"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move down"), :error)
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
      add_flash(_("No fields were selected to move up") % "", :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move up"), :error)
    else
      if first_idx > 0
        @edit[:selected_reports][first_idx..last_idx].reverse_each do |field|
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
      add_flash(_("No fields were selected to move down"), :error)
      return
    end
    consecutive, first_idx, last_idx = selected_menu_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move down"), :error)
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
    @edit[:selected_reports].each_with_index do |nf, idx|
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
    @edit[:temp_arr] = []
    id = session[:node_selected].split('__')
    selected = id[1].split(':')
    @edit[:new].each do |a1, a2|
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
    # session[:changed] = @changed = false
    @edit = {}
    @edit[:new] = []
    @edit[:key] = "menu_edit__#{session[:role_choice] ? session[:role_choice] : "new"}"

    @edit[:temp_arr] = []
    @edit[:form_vars] = {}
    @edit[:current] = []
    @edit[:new] = @rpt_menu unless @rpt_menu.nil?
    user = current_user
    @edit[:user_typ] = user.admin_user?
    @edit[:user_group] = user.current_group.id
    @edit[:group_reports] = []
    menu_set_reports_for_group
    @edit[:current] = copy_hash(@edit[:new]) unless @edit[:new].nil?
    session[:edit] = @edit
  end

  def menu_set_reports_for_group
    @edit[:new].each do |r|
      r.each_slice(2) do |menu, section|
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

  # Render the view data for the grid view
  def menu_folders(view)
    view.compact.map do |row|
      row_id = nil

      if @edit[:user_typ]
        # if user is admin/super admin, no need to add special characters in id
        row_id = "i_#{row}"
      elsif @edit[:group_reports].empty?
        # if group does not own any reports then add special characters in id, they cannot delete any folders.
        row_id = "__|i_#{row}"
      else
        prefix = "|-|"

        # FIXME: this is jast .last really, on purpose?
        @edit[:group_reports].each do |rep|
          # need to check if report is not owned by user add special character to the row id so it can be tracked in JS and folder cannnot be deleted in menu editor
          nodes = rep.split('/')
          val = session[:node_selected].split('__')[0]
          if val == "b"
            # if top node
            if nodes[0] == row
              # if report belongs to group
              row_id = "i_#{row}"
            else
              # if report is owned by other group
              row_id = "#{prefix}i_#{row}"
            end
          else
            # if second level folder node
            if nodes[1] == row
              # if report belongs to group
              row_id = "i_#{row}"
              # break
            else
              # if report is owned by other group
              row_id = "#{prefix}i_#{row}"
            end
          end
        end
      end

      {:id   => row_id,
       :text => row}
    end
  end

  def edit_folder
    session[:node_selected] = "xx-b__Report Menus for #{session[:role_choice]}" if params[:button] == "reset" || params[:button] == "default"  # resetting node in case reset button is pressed
    @selected = session[:node_selected].split('__')
    @folders = []
    @edit[:folders] = []

    # calculating selected reports for selected folder
    if session[:node_selected] == "xx-b__Report Menus for #{session[:role_choice]}"
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
    @grid_folders = menu_folders(@edit[:folders])
  end

  def menu_get_all
    roles, title = get_group_roles
    @sb[:menu] = {}
    roles.sort_by { |a| a.name.downcase }.each do |r|
      @sb[:menu][r.id] = r.name
    end
    @right_cell_text = title == "My #{ui_lookup(:model => "MiqGroup")}" ?
      title :
      _("All %{models}") % {:models => ui_lookup(:models => "MiqGroup")}
    @right_cell_div = "role_list"
    @menu_roles_tree = nil
  end

  def get_menu(_nodeid)
    # build menu for selected role
    get_tree_data
    @right_cell_div  = "role_list"
    @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => session[:role_choice], :model => ui_lookup(:model => "MiqGroup")}
  end

  # Build the main roles/menu editor tree
  def build_roles_tree
    TreeBuilderReportRoles.new('roles_tree', 'roles', @sb)
  end

  def get_group_roles
    if super_admin_user?
      roles = MiqGroup.non_tenant_groups
      title  = "All #{ui_lookup(:models => "MiqGroup")}"
    else
      title  = "My #{ui_lookup(:model => "MiqGroup")}"
      roles = [current_user.current_group]
    end
    return roles, title
  end
end
