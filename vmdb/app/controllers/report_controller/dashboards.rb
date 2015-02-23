module ReportController::Dashboards
  extend ActiveSupport::Concern

  def db_seq_edit
    assert_privileges("db_seq_edit")
    case params[:button]
    when "cancel"
      @edit = session[:edit] = nil  # clean out the saved info
      add_flash(_("Edit of Dashboard Sequence was cancelled by the user"))
      replace_right_cell
    when "save"
      return unless load_edit("db_edit__seq","replace_cell__explorer")
      err = false
      dashboard_order = Array.new
      @edit[:new][:dashboard_order].each do |n|
        dashboard_order.push(MiqWidgetSet.where_unique_on(n, nil, nil).first.id)
      end
        g = MiqGroup.find(from_cid(@sb[:nodes][2]))
        g.settings ||= Hash.new
        g.settings[:dashboard_order] ||= Hash.new
        g.settings[:dashboard_order] = dashboard_order
        if g.save
          AuditEvent.success(build_saved_audit(g, @edit))
        else
          g.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          err = true
        end
      if !err
        add_flash(_("Dashboard Sequence was saved"))
        @edit = session[:edit] = nil    # clean out the saved info
        replace_right_cell(:replace_trees => [:db])
      else
        @in_a_form = true
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "reset", nil # Reset or first time in
      db_seq_edit_screen
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      @lock_tree = true
      session[:changed] = @changed = false
      replace_right_cell
    end
  end

  def db_new
    assert_privileges("db_new")
    db_edit
  end

  def db_edit
    case params[:button]
      when "cancel"
        @db = MiqWidgetSet.find_by_id(session[:edit][:db_id]) if session[:edit] && session[:edit][:db_id]
        if !@db || @db.id.blank?
          add_flash(_("Add of new %s was cancelled by the user") % "Dashboard")
        else
          add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>"Dashboard", :name=>@db.name})
        end
        get_node_info
        @edit = session[:edit] = nil # clean out the saved info
        @db = nil
        replace_right_cell
      when "add","save"
        assert_privileges("db_#{@edit[:db_id] ? "edit" : "new"}")
        @db = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new # get the current record
        db_fields_validation
        db_set_record_vars
        if params[:button] == "add"
          g = MiqGroup.find(from_cid(@sb[:nodes][2]))
          @db.owner = g
        end
        if @flash_array.nil? && @db.save
          db_save_members
          AuditEvent.success(build_saved_audit(@db, @edit))
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>"Dashboard", :name=>@db.name})
          if params[:button] == "add"
            widgetset = MiqWidgetSet.where_unique_on(@edit[:new][:name], nil, nil).first
            settings = g.settings ? g.settings : Hash.new
            settings[:dashboard_order] = settings[:dashboard_order] ? settings[:dashboard_order] : Array.new
            settings[:dashboard_order].push(widgetset.id) if !settings[:dashboard_order].include?(widgetset.id)
            g.save
          end
          params[:id] = @db.id.to_s   # reset id in params for show
          @edit = session[:edit] = nil    # clean out the saved info
          replace_right_cell(:replace_trees => [:db])
        else
          @db.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        end
      else
        add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
        @db = params[:id] && params[:id] != "new" ? find_by_id_filtered(MiqWidgetSet, params[:id]) : MiqWidgetSet.new
        db_set_form_vars
        session[:changed] = false
        @in_a_form = true
        @lock_tree = true
        replace_right_cell
    end
  end

  # Delete all selected or single displayed action(s)
  def db_delete
    assert_privileges("db_delete")
    db = MiqWidgetSet.find_by_id(params[:id])       #temp var to determine the parent node of deleted items
    process_elements(db, MiqWidgetSet, "destroy")
    unless flash_errors?
        add_flash(_("The selected %s was deleted") % "Dashboard",
                  :info, true)
    end
    g = MiqGroup.find(from_cid(@sb[:nodes][2].split('_').first))
    #delete dashboard id from group settings and save
    db_order = g.settings && g.settings[:dashboard_order] ? g.settings[:dashboard_order] : nil
    if db_order
      db_order.delete(db.id)
    end
    g.save
    nodes = x_node.split('-')
    self.x_node = "#{nodes[0]}-#{nodes[1]}-#{nodes[2].split('_').first}"
    replace_right_cell(:replace_trees => [:db])
  end

  def db_form_field_changed
    return unless load_edit("db_edit__#{params[:id]}","replace_cell__explorer")
    db_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial=>"db_form")
        #url to be used in url in miqDropComplete method
        page << "miq_widget_dd_url = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      if ["up","down"].include?(params[:button])
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg") unless @refresh_div && @refresh_div != "column_lists"
        page.replace(@refresh_div, :partial=>@refresh_partial, :locals=>{:action=>"db_seq_edit"}) if @refresh_div
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  # A widget has been dropped
  def db_widget_dd_done
    set_edit_new_cols
    db_available_widgets_xml
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial=>"db_form")
        #url to be used in url in miqDropComplete method
        page << "miq_widget_dd_url = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def db_widget_remove
    return unless load_edit("db_edit__#{params[:id]}","replace_cell__explorer")
    @db = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new
    w = params[:widget].to_i
    @edit[:new][:col1].delete(w) if @edit[:new][:col1].include?(w)
    @edit[:new][:col2].delete(w) if @edit[:new][:col2].include?(w)
    @edit[:new][:col3].delete(w) if @edit[:new][:col3].include?(w)
    db_available_widgets_xml
    @in_a_form = true
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial=>"db_form")
        #url to be used in url in miqDropComplete method
        page << "miq_widget_dd_url = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  private

  def set_edit_new_cols
    if params[:col1] || params[:col2] || params[:col3]
      if params[:col1] && params[:col1] != [""]
        @edit[:new][:col1] = params[:col1].collect{|w| w.split("_").last.to_i}
        @edit[:new][:col2].delete_if{|w| @edit[:new][:col1].include?(w)}
        @edit[:new][:col3].delete_if{|w| @edit[:new][:col1].include?(w)}
      elsif params[:col2] && params[:col2] != [""]
        @edit[:new][:col2] = params[:col2].collect{|w| w.split("_").last.to_i}
        @edit[:new][:col1].delete_if{|w| @edit[:new][:col2].include?(w)}
        @edit[:new][:col3].delete_if{|w| @edit[:new][:col2].include?(w)}
      elsif params[:col3] && params[:col3] != [""]
        @edit[:new][:col3] = params[:col3].collect{|w| w.split("_").last.to_i}
        @edit[:new][:col1].delete_if{|w| @edit[:new][:col3].include?(w)}
        @edit[:new][:col2].delete_if{|w| @edit[:new][:col3].include?(w)}
      end
    end
  end

  def db_get_node_info
    @sb[:nodes] = x_node.split('-')
    if @sb[:nodes].length == 1
      @temp[:default_ws] = MiqWidgetSet.where_unique_on("default", nil, nil).where(:read_only => true).first
      @right_cell_text = _("All %s") % "Dashboards"
      @right_cell_div  = "db_list"
      @temp[:db_nodes] = Hash.new
      @temp[:db_nodes_order] = [@temp[:default_ws].name, "All Groups"]

      @temp[:db_nodes][@temp[:default_ws].name] = Hash.new
      @temp[:db_nodes][@temp[:default_ws].name][:id] = "xx-#{to_cid(@temp[:default_ws].id)}"
      @temp[:db_nodes][@temp[:default_ws].name][:text] = "#{@temp[:default_ws].description} (#{@temp[:default_ws].name})"
      @temp[:db_nodes][@temp[:default_ws].name][:title] = "#{@temp[:default_ws].description} (#{@temp[:default_ws].name})"
      @temp[:db_nodes][@temp[:default_ws].name][:glyph] = "fa fa-dashboard"

      @temp[:db_nodes]["All Groups"] = Hash.new
      @temp[:db_nodes]["All Groups"][:id] = "xx-g"
      @temp[:db_nodes]["All Groups"][:glyph] = "pficon pficon-folder-close"
      @temp[:db_nodes]["All Groups"][:title] = "All Groups"
      @temp[:db_nodes]["All Groups"][:text] = "All Groups"
    elsif @sb[:nodes].length == 2 && @sb[:nodes].last == "g"
      #All groups node is selected
      @temp[:miq_groups] = MiqGroup.all
      @right_cell_div  = "db_list"
      @right_cell_text = _("All %s") % ui_lookup(:models=>"MiqGroup")
    elsif @sb[:nodes].length == 3 && @sb[:nodes][1] == "g_g"
      g = MiqGroup.find(from_cid(@sb[:nodes].last))
      @right_cell_text = _("%{model} for \"%{name}\"") % {:model=>"Dashboards", :name=>g.description}
      @right_cell_div  = "db_list"
      widgetsets = MiqWidgetSet.find_all_by_owner_type_and_owner_id("MiqGroup",g.id)
      @temp[:widgetsets] = Array.new
      if g.settings && g.settings[:dashboard_order]
        g.settings[:dashboard_order].each do |ws_id|
          widgetsets.each do |ws|
            @temp[:widgetsets].push(ws) if ws_id == ws.id && !@temp[:widgetsets].include?(ws)
          end
        end
      else
        widgetsets.sort{|a,b| a.name <=> b.name}.each do |ws|
          @temp[:widgetsets].push(ws)
        end
      end
    elsif (@sb[:nodes].length == 4 && @sb[:nodes][1] == "g_g") ||
        (@sb[:nodes].length == 2 && @sb[:nodes].first == "xx")
      #default dashboard nodes is selected or one under a specific group is selected
      #g = MiqGroup.find(@sb[:nodes][2])
      @record = @db = MiqWidgetSet.find(from_cid(@sb[:nodes].last))
      @right_cell_text = _("%{model} \"%{name}\"") % {:model=>"Dashboard", :name=>"#{@db.description} (#{@db.name})"}
      @right_cell_div  = "db_list"
      @sb[:new] = Hash.new
      @sb[:new][:name] = @db.name
      @sb[:new][:description] = @db.description
      @sb[:new][:locked] = @db[:set_data] && @db[:set_data][:locked] ? @db[:set_data][:locked] : true
      @sb[:new][:col1] = @db[:set_data] && @db[:set_data][:col1] ? @db[:set_data][:col1] : Array.new
      @sb[:new][:col2] = @db[:set_data] && @db[:set_data][:col2] ? @db[:set_data][:col2] : Array.new
      @sb[:new][:col3] = @db[:set_data] && @db[:set_data][:col3] ? @db[:set_data][:col3] : Array.new
    end
  end

  def db_get_form_vars
    @in_a_form = true
    @db = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new
    if ["up","down"].include?(params[:button])
      db_move_cols_up if params[:button] == "up"
      db_move_cols_down if params[:button] == "down"
    else
      @edit[:new][:name] = params[:name] if params[:name]
      @edit[:new][:description] = params[:description] if params[:description]
      if params[:locked]
        @edit[:new][:locked] = params[:locked].to_i == 1
      end
      if params[:widget]                # Make sure we got a widget in
        w = params[:widget].to_i
        if @edit[:new][:col3].length < @edit[:new][:col1].length &&
            @edit[:new][:col3].length < @edit[:new][:col2].length
          @edit[:new][:col3].insert(0, w)
        elsif @edit[:new][:col2].length < @edit[:new][:col1].length
          @edit[:new][:col2].insert(0, w)
        else
          @edit[:new][:col1].insert(0, w)
        end
        db_available_widgets_xml
      end
      set_edit_new_cols
    end
  end

  def db_set_record_vars
    @db.name = @edit[:new][:name]
    @db.description = @edit[:new][:description]
    @db.updated_on = Time.now.utc
    @db.set_data = Hash.new if !@db.set_data
    @db.set_data[:col1] = Array.new if !@db.set_data[:col1] && !@edit[:new][:col1].empty?
    @db.set_data[:col2] = Array.new if !@db.set_data[:col2] && !@edit[:new][:col2].empty?
    @db.set_data[:col3] = Array.new if !@db.set_data[:col3] && !@edit[:new][:col3].empty?
    @db.set_data[:col1] = @edit[:new][:col1]
    @db.set_data[:col2] = @edit[:new][:col2]
    @db.set_data[:col3] = @edit[:new][:col3]
    @db.set_data[:locked] = @edit[:new][:locked]
  end

  def db_save_members
    widgets = Array.new
    @db.set_data[:col1].each do |w|
      wg = MiqWidget.find_by_id(w)
      widgets.push(wg) if wg
    end
    @db.set_data[:col2].each do |w|
      wg = MiqWidget.find_by_id(w)
      widgets.push(wg) if wg
    end
    @db.set_data[:col3].each do |w|
      wg = MiqWidget.find_by_id(w)
      widgets.push(wg) if wg
    end
    @db.replace_children(widgets)
    @db.members.each{|w| w.create_initial_content_for_user(session[:userid])} # Generate content if not there
  end

  def db_fields_validation
    if @edit[:new][:name] && @edit[:new][:name].index('|')
      add_flash(_("%{field} cannot contain \"%{character}\"") % {:field=>"Name", :character=>"|"}, :error)
      return
    end
    #no need to check this for default dashboard, it doesn't belong to any group
    if @sb[:nodes][2] != "d"
      ws = MiqWidgetSet.find_all_by_owner_id(@sb[:nodes][2])
      #make sure description is unique within group
      ws.each do |w|
        if w.description == @edit[:new][:description] && (@edit[:db_id] && w.id != @edit[:db_id])
          add_flash(_("%s must be unique for this group") % "Tab Title", :error)
          break
        end
      end
    end
    if @edit[:new][:col1].empty? && @edit[:new][:col2].empty? && @edit[:new][:col3].empty?
      add_flash(_("%s must be selected") % "One widget", :error)
      return
    end
  end

  def db_set_form_vars
    @timezone_abbr = get_timezone_abbr("server")
    @edit = Hash.new
    @edit[:db_id] = @db.id
    @edit[:read_only] = @db.read_only ? true : false

    # Remember how this edit started
    @edit[:type] = params[:id] ? "db_edit" : "db_new"
    @edit[:key]  = params[:id]  ? "db_edit__#{@db.id}" : "db_edit__new"
    @edit[:new] = Hash.new
    @edit[:new][:name] = @db.name
    @edit[:new][:description] = @db.description
    @edit[:new][:locked] = @db[:set_data] && @db[:set_data][:locked] ? @db[:set_data][:locked] : false
    @edit[:new][:col1] = @db[:set_data] && @db[:set_data][:col1] ? @db[:set_data][:col1] : Array.new
    @edit[:new][:col2] = @db[:set_data] && @db[:set_data][:col2] ? @db[:set_data][:col2] : Array.new
    @edit[:new][:col3] = @db[:set_data] && @db[:set_data][:col3] ? @db[:set_data][:col3] : Array.new
    db_available_widgets_xml
    @edit[:current] = copy_hash(@edit[:new])
  end

  def db_seq_edit_screen
    @in_a_form = true
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new][:dashboard_order] = Array.new
    g = MiqGroup.find(from_cid(@sb[:nodes][2]))
    @sb[:group_desc] = g.description    #saving for cell header
    if g.settings && g.settings[:dashboard_order]
      dbs = g.settings[:dashboard_order]
      dbs.each do |db|
        ws = MiqWidgetSet.find(db)
        @edit[:new][:dashboard_order].push(ws.name)
      end
    else
      dbs = MiqWidgetSet.find_all_by_owner_type_and_owner_id("MiqGroup",g.id)
      dbs.sort{|a,b| a.name <=> b.name}.each do |ws|
        @edit[:new][:dashboard_order].push(ws.name)
      end
    end

    @edit[:key] = "db_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def db_available_widgets_xml
    # Build the available widgets for the pulldown
    col_widgets = @edit[:new][:col1] +
                  @edit[:new][:col2] +
                  @edit[:new][:col3]
    if @sb[:nodes].length == 2 && @sb[:nodes][1] != "g"
      #default dashboard selected
      @available_widgets = MiqWidget.available_for_all_roles
    else
      g = MiqGroup.find(from_cid(@sb[:nodes][2].split('_').first))
      @available_widgets = MiqWidget.available_for_group(g)
    end
    @available_widgets.sort_by! { |w| [w.content_type, w.title.downcase] }

    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")
    # Create root element
    root = xml.add_element("complete")
    opt = root.add_element("option", {"value"=>"","img_src"=>"/images/icons/24/add_widget.png"})
    opt.text = "Add a Widget"
    opt.add_attribute("selected","true")
    @available_widgets.each do |w|
      unless col_widgets.include?(w.id) || !w.enabled
        image, tip = case w.content_type
                      when "rss"
                        ["rssfeed", "Add this RSS Feed Widget"]
                      when "chart"
                        ["piechart", "Add this Chart Widget"]
                      when "report"
                        ["report", "Add this Report Widget"]
                      when "menu"
                        ["menu", "Add this Menu Widget"]
        end
        w.title.gsub!(/'/,"&apos;")     # Need to escape single quote in title to load toolbar
        opt = root.add_element("option", {"value"=>w.id,"img_src"=>"/images/icons/24/button_#{image}.png"})
        opt.text = CGI.escapeHTML(w.title)
      end
    end

    if @available_widgets.blank?
      opt = root.add_element("option", {"value"=>"","img_src"=>"/images/icons/24/add_widget.png"})
      opt.text = "No Widgets available to add"
    end
    @widgets_menu_xml = xml.to_s.html_safe
  end

  def db_move_cols_up
    return unless load_edit("db_edit__seq","replace_cell__explorer")
    if !params[:seq_fields] || params[:seq_fields].length == 0 || params[:seq_fields][0] == ""
      add_flash(_("No %s were selected to move up") % "fields", :error)
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
      return
    end
    consecutive, first_idx, last_idx = db_selected_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move up") % "fields", :error)
    else
      if first_idx > 0
        @edit[:new][:dashboard_order][first_idx..last_idx].reverse.each do |field|
          pulled = @edit[:new][:dashboard_order].delete(field)
          @edit[:new][:dashboard_order].insert(first_idx - 1, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def db_move_cols_down
    return unless load_edit("db_edit__seq","replace_cell__explorer")
    if !params[:seq_fields] || params[:seq_fields].length == 0 || params[:seq_fields][0] == ""
      add_flash(_("No %s were selected to move down") % "fields", :error)
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
      return
    end
    consecutive, first_idx, last_idx = db_selected_consecutive?
    if ! consecutive
      add_flash(_("Select only one or consecutive %s to move down") % "fields", :error)
    else
      if last_idx < @edit[:new][:dashboard_order].length - 1
        insert_idx = last_idx + 1   # Insert before the element after the last one
        insert_idx = -1 if last_idx == @edit[:new][:dashboard_order].length - 2 # Insert at end if 1 away from end
        @edit[:new][:dashboard_order][first_idx..last_idx].each do |field|
          pulled = @edit[:new][:dashboard_order].delete(field)
          @edit[:new][:dashboard_order].insert(insert_idx, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def db_selected_consecutive?
    first_idx = last_idx = 0
    @edit[:new][:dashboard_order].each_with_index do |nf,idx|
      first_idx = idx if nf == params[:seq_fields].first
      if nf == params[:seq_fields].last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > params[:seq_fields].length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end

  #Build the main dashboards tree
  def build_db_tree(type=:db, name=:db_tree)
    x_tree_init(name, type, 'MiqWidgetSet', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = "All Dashboards"
    root[:tooltip] = "All Dashboards"
    root[:icon]    = "folder.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end
end
