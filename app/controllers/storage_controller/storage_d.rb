# Setting Accordion methods included in OpsController.rb
module StorageController::StorageD
  extend ActiveSupport::Concern

  def storage_tree_select
    @lastaction = "explorer"
    _typ, id = params[:id].split("_")
    @record = Storage.find(from_cid(id))
  end

  def storage_list
    @lastaction = "storage_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:storage_sortcol].nil? ? 0 : session[:storage_sortcol].to_i
    @sortdir = session[:storage_sortdir].nil? ? "ASC" : session[:storage_sortdir]

    @view, @pages = get_view(Storage) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:storage_sortcol] = @sortcol
    session[:storage_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|
        page << javascript_prologue
        page.replace("gtl_div", :partial => "layouts/x_gtl", :locals => {:action_url => "storage_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def miq_search_node
    options = {:model => "Storage"}
    process_show_list(options)
    @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "Datastore")}
  end

  private #######################

  # Get information for an event
  def storage_build_tree
    TreeBuilderStorage.new("storage_tree", "storage", @sb)
  end

  def storage_get_node_info(treenodeid)
    if treenodeid == "root"
      options = {:model => "Storage"}
      process_show_list(options)
      @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => "Storage")}
    else
      nodes = treenodeid.split("-")
      if nodes[0] == "ds"
        @right_cell_div = "storage_details"
        @record = @storage = Storage.find_by_id(from_cid(nodes.last))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name => @storage.name, :model => ui_lookup(:model => "Storage")}
      else
        miq_search_node
       end
    end
  end
end
