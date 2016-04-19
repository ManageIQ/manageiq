# Setting Accordion methods included in OpsController.rb
module StorageController::StoragePod
  extend ActiveSupport::Concern

  def storage_pod_tree_select
    _typ, id = params[:id].split("_")
    @record = Storage.find(from_cid(id))
  end

  def storage_pod_list
    @lastaction = "storage_pod_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:dsc_sortcol].nil? ? 0 : session[:dsc_sortcol].to_i
    @sortdir = session[:dsc_sortdir].nil? ? "ASC" : session[:dsc_sortdir]
    dsc_id = x_node.split('-').last
    folder = EmsFolder.where(:id => from_cid(dsc_id))
    @view, @pages = get_view(Storage, :where_clause => ["storages.id in (?)", folder.first.storages.collect(&:id)]) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:ct_sortcol] = @sortcol
    session[:ct_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|
        page << javascript_prologue
        page.replace("gtl_div", :partial => "layouts/x_gtl", :locals => {:action_url => "template_list"})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  private #######################

  def storage_pod_get_node_info(treenodeid)
    if treenodeid == "root"
      @folders = EmsFolder.where(:type => "StorageCluster").sort
      # to check if Add customization template button should be enabled
      @right_cell_text = _("All Datastore Clusters")
      @right_cell_div  = "storage_pod_list"
    else
      nodes = treenodeid.split("-")
      if nodes[0] == "ds"
        @right_cell_div = "storage_details"
        @record = @storage_pod= Storage.find_by_id(from_cid(nodes[1]))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => "Storage")}
      else
        storage_pod_list
        dsc_id= x_node.split('-').last
        @record = @storage_pod = EmsFolder.find_by_id(from_cid(dsc_id))
        @right_cell_text = _("Datastores in cluster %{name}") % {:name => @record.name}
        @right_cell_div  = "storage_list"
      end
    end
  end


  # Get information for an event
  def storage_pod_build_tree
    TreeBuilderStoragePod.new("storage_pod_tree", "storage_pod", @sb)
  end


end
