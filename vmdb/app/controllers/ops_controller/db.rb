# Database Accordion methods included in OpsController.rb
module OpsController::Db
  extend ActiveSupport::Concern

  # Show list of VMDB tables or settings
  def db_list(exp=nil)
    @lastaction = "db_list"
    @force_no_grid_xml = true
    model = case @sb[:active_tab] # Build view based on tab selected
      when "db_connections"
        VmdbDatabaseConnection
      when "db_details"
        VmdbTableEvm
      when "db_indexes"
        VmdbIndex
      when "db_settings"
        VmdbDatabaseSetting
    end
    #@explorer = true if model == VmdbIndex

    if model == VmdbIndex
      #building a filter with expression to only show VmdbTableEvm tables only
      cond = Array.new
      cond_hash = Hash.new
      cond_hash["="] = {"value"=> "VmdbTableEvm","field"=>"VmdbIndex.vmdb_table-type"}
      cond.push(cond_hash)

      condition = Hash.new
      condition["and"] = Array.new
      cond.each do |c|
        condition["and"].push(c)
      end
      exp =  MiqExpression.new(condition)
    elsif model == VmdbDatabaseConnection
      @zones = Zone.find(:all).sort{|a,b| a.name <=> b.name}.collect{|z| [z.name, z.name]}
      # for now we dont need this pulldown, need ot get a method that could give us a list of workers for filter pulldown
      #@workers = MiqWorker.all(:order=>"type ASC").uniq.sort{|a,b| a.type <=> b.type}.collect{|w| [w.friendly_name, w.id]}
    end

    @view, @pages = get_view(model, :filter=>exp ? exp : nil) # Get the records (into a view) and the paginator

    @ajax_paging_buttons = true
    @no_checkboxes = true
    @showlinks = true # Need to set @showlinks if @no_checkboxes is set to true
    @current_page = @pages[:current] if @pages != nil # save the current page number

    # Came in from outside show_list partial
    if params[:action] == "list_view_filter" || params[:ppsetting]   || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|                    # Use RJS to update the display
        page.replace_html("gtl_div", :partial => 'layouts/x_gtl', :locals=>{:action_url=>"db_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def list_view_filter
    @sb[:condition] = Array.new
    @sb[:zone_name] = params[:zone_name] if params[:zone_name]
    @sb[:filter_text] = params[:filter][:text] if params[:filter] && params[:filter][:text]

    if params[:zone_name] && params[:zone_name] != "all"
      @sb[:zone_name] = params[:zone_name]
      cond_hash = Hash.new
      cond_hash["="] = {"value"=> params[:zone_name],"field"=>"VmdbDatabaseConnection-zone.name"}
      @sb[:condition].push(cond_hash)
    end
    if params[:filter] && params[:filter][:text] != ""
      #@sb[:cond] =  ["vmdb_database_connection.address like ?", params[:filter][:text]]
      cond_hash = Hash.new
      cond_hash["like"] = {"value"=> params[:filter][:text],"field"=>"VmdbDatabaseConnection-address"}
      @sb[:condition].push(cond_hash)
    end
    condition = Hash.new
    condition["and"] = Array.new
    @sb[:condition].each do |c|
      condition["and"].push(c)
    end
    exp = MiqExpression.new(condition)
    #forcing to refresh the view when filtering results
    @_params[:refresh] = "y"
    db_list(exp)
  end

  # VM clicked on in the explorer right cell
  def x_show
    #@explorer = true
    @record = VmdbIndex.find_by_id(from_cid(params[:id]))
    params[:id] = x_build_node_id(@record)  # Get the tree node id
    tree_select
  end

  def db_table_export
    ids = find_checked_items
    ids = [params[:id]] if ids.empty?
    session[:export_fname] = ids.length == 1 ?
            "EVM_#{VmdbTable.find_by_id(from_cid(ids[0])).name}_TABLE_#{format_timezone(Time.now, Time.zone, "fname")}.zip" :
            "EVM_TABLES_#{format_timezone(Time.now, Time.zone, "fname")}.zip"
    unless params[:task_id]                       # First time thru, kick off the report generate task
      initiate_wait_for_task(:task_id => VmdbTable.export_queue(ids.map!(&:to_i)))
      return
    end
    miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
    if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
      add_flash(_("Export generation returned: Status [%{status}] Message [%{message}]") % {:status=>miq_task.status, :message=>miq_task.message}, :error)
      render :update do |page|                      # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
    else
      session[:export_data_id] = miq_task.id
      render :update do |page|                      # Use JS to update the display
        page << "miqSparkle(false);"
        page << "DoNav('#{url_for(:action=>"send_download_data")}');"
      end
    end
  end

  def db_table_analyze
    ids = find_checked_items
    ids = [params[:id]] if ids.empty?
    VmdbTable.analyze_queue(ids.collect(&:to_i))
    render :update do |page|                      # Use JS to update the display
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end

  def db_table_reindex
    ids = find_checked_items
    ids = [params[:id]] if ids.empty?
    VmdbTable.reindex_queue(ids.collect(&:to_i))
    render :update do |page|                      # Use JS to update the display
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end

  def db_table_vacuum
    ids = find_checked_items
    ids = [params[:id]] if ids.empty?
    VmdbTable.vacuum_queue(ids.collect(&:to_i))
    render :update do |page|                      # Use JS to update the display
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end

  def db_table_vacuum_full
    ids = find_checked_items
    ids = [params[:id]] if ids.empty?
    VmdbTable.vacuum_full_queue(ids.collect(&:to_i))
    render :update do |page|                      # Use JS to update the display
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << "miqSparkle(false);"
    end
  end


  def send_download_data
    export_data = MiqTask.find_by_id(session[:export_data_id]).task_results
    disable_client_cache
    send_data(export_data, :filename => session[:export_fname], :type=>"application/zip" )
  end

  private #######################

  # Build a VMDB tree for Database accordion
  def db_build_tree
    TreeBuilderOpsVmdb.new("vmdb_tree", "vmdb", @sb)
  end

  # Get information for a DB tree node
  def db_get_info(nodetype)
    if x_node == "root"
      # If root node is selected
      if @sb[:active_tab] == "db_summary"
        @record = VmdbDatabase.my_database
        @right_cell_text = _("%s Summary") % "VMDB"
      elsif @sb[:active_tab] == "db_utilization"
        @record = VmdbDatabase.my_database
        perf_gen_init_options               # Initialize perf chart options, charts will be generated async
        @sb[:record_class] = @record.class.base_class.name  # Hang on to record class/id for async trans
        @sb[:record_id] = @record.id
        @right_cell_text = _("%s Utilization") % "VMDB"
      else
        @right_cell_text = case @sb[:active_tab]
        when "db_connections"
          @right_cell_text = _("%s Client Connections") % "VMDB"
        when "db_details"
          @right_cell_text = _("All %s") % ui_lookup(:models=>"VmdbTable")
        when "db_indexes"
          @right_cell_text = _("All %s Indexes") % "VMDB"
        else
          @right_cell_text = _("%s Settings") % "VMDB"
        end
        @force_no_grid_xml = true
        db_list
      end
      @tab_text = "Tables"
    else
      # If table is selected
      if @sb[:active_tab] == "db_indexes" || params[:action] == "x_show"
        nodes = x_node.split('-')
        if nodes.first == "xx"
          tb = VmdbTableEvm.find_by_id(from_cid(nodes.last))
          @temp[:indexes] = get_indexes(tb)
          @right_cell_text = _("Indexes for %{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"VmdbTable"), :name=>tb.name}
          @tab_text = "#{tb.name}: Indexes"
        else
          @temp[:vmdb_index] = VmdbIndex.find_by_id(from_cid(nodes.last))
          @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"VmdbIndex"), :name=>@temp[:vmdb_index].name}
          @tab_text = @temp[:vmdb_index].name
        end
      elsif @sb[:active_tab] == "db_utilization"
        @record = VmdbTable.find_by_id(from_cid(x_node.split('-').last))
        perf_gen_init_options               # Initialize perf chart options, charts will be generated async
        @sb[:record_class] = @record.class.base_class.name  # Hang on to record class/id for async trans
        @sb[:record_id] = @record.id
        @right_cell_text = _("%s Utilization") % "VMDB Table \"#{@record.name}\""
        @tab_text = @record.name
      else
        @sb[:active_tab] = "db_details"
        @temp[:table] = VmdbTable.find_by_id(from_cid(x_node.split('-').last))
        @temp[:indexes] = get_indexes(@temp[:table])
        @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"VmdbTable"), :name=>@temp[:table].name}
        @tab_text = @temp[:table].name
      end
    end
  end

  def get_indexes(tb)
    indexes = Array.new
    tb.vmdb_indexes.sort{|a,b| a.name <=> b.name}.each do |idx|
      indexes.push(idx) if idx.vmdb_table.type == "VmdbTableEvm"
    end
    return indexes
  end

  def db_refresh
    assert_privileges("db_refresh")
    db_get_info(x_node)
    render :update do |page|
      page.replace_html(@sb[:active_tab], :partial=>"db_details_tab")
      page << "miqSparkle(false);"    # Need to turn off sparkle in case original ajax element gets replaced
    end
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    return x_get_child_nodes_dynatree(x_active_tree, id)
  end

end
