module ApplicationController::TreeSupport
  extend ActiveSupport::Concern

  def squash_toggle
    @record = find_record
    item = "h_#{@record.name}"
    render :update do |page|
      page << javascript_prologue
      if session[:squash_open] == false
        page << "$('#squash_img i').attr('class','fa fa-angle-double-up fa-lg')"
        page << "$('#squash_img').prop('title', 'Collapse All')"
        page << "miqTreeToggleExpand('#{j_str(session[:tree_name])}', true)"
        session[:squash_open] = true
      else
        page << "$('#squash_img i').attr('class','fa fa-angle-double-down fa-lg')"
        page << "$('#squash_img').prop('title', 'Expand All')"
        page << "miqTreeToggleExpand('#{j_str(session[:tree_name])}', false);"
        page << "miqTreeActivateNodeSilently('#{j_str(session[:tree_name])}', '#{item}');"
        session[:squash_open] = false
      end
    end
  end

  def find_record
    # TODO: This logic should probably be reversed - fixed list for VmOrTemplate.
    # (Better yet, override the method only in VmOrTemplate related controllers.)
    if %w(host container_replicator container_group container_node container_image ext_management_system).include? controller_name
      identify_record(params[:id], controller_name.classify)
    else
      identify_record(params[:id], VmOrTemplate)
    end
  end

  def tree_autoload
    @edit ||= session[:edit] # Remember any previous @edit
    render :json => tree_add_child_nodes(params[:id])
  end

  def tree_add_child_nodes(id)
    tree_name = params[:tree] || x_active_tree
    tree_type = tree_name.to_s.sub(/_tree$/, '')
    tree_klass = x_tree(tree_name)[:klass_name]

    # FIXME after euwe: build_ae_tree
    tree_type = 'catalog' if controller_name == 'catalog' && tree_type == 'automate'

    nodes = TreeBuilder.tree_add_child_nodes(@sb, tree_klass, id, tree_type)
    TreeBuilder.convert_bs_tree(nodes)
  end

  def tree_exists?(tree_name)
    @sb[:trees].try(:key?, tree_name.to_s)
  end

  private ############################

  # Build the H&C or V&T tree with nodes selected
  def build_belongsto_tree(selected_ids, vat = false, save_tree_in_session = true, rp_only = false)
    @selected_ids = selected_ids
    @vat = true if vat
    # for Alert profile assignments where checkboxes are only required on Resource Pools
    @rp_only  = true if rp_only
    providers = []                          # Array to hold all providers
    ExtManagementSystem.all.each do |ems| # Go thru all of the providers
      if !@rp_only || (@rp_only && ems.resource_pools.count > 0)
        ems_node = {
          :key         => "#{ems.class.name}_#{ems.id}",
          :title       => ems.name,
          :checkable   => !@edit.nil?,
          :tooltip     => "#{ui_lookup(:table => "ems_infras")}: #{ems.name}",
          :cfmeNoClick => true,
          :icon        => ActionController::Base.helpers.image_path("svg/vendor-#{ems.image_name}.svg")
        }
        if @vat || @rp_only
          ems_node[:hideCheckbox] = true
        end
        ems_node[:select] = true if selected_ids.include?(ems_node[:key])  # Check if tag is assigned
        ems_kids = []
        kids_checked = false
        ems.children.each do |c|
          kid_node, kid_checked = user_get_tree_node(c, ems_node[:key]) # Add child node(s) to tree
          ems_kids += kid_node  # Add child node(s) to tree
          kids_checked ||= kid_checked  # Remember if any kid is checked
        end
        ems_node[:children] = ems_kids unless ems_kids.empty?
        ems_node[:expand] = true if kids_checked
        providers.push(ems_node)
      end
    end

    if save_tree_in_session
      session[:tree] = vat ? "vat" : "hac"
      session["#{session[:tree]}_tree".to_sym] = TreeBuilder.convert_bs_tree(providers).to_json # Add ems node array to root of tree
    else
      TreeBuilder.convert_bs_tree(providers).to_json # Return tree nodes to the caller
    end
  end

  # Return tree node(s) for the passed in folder/datacenter/host/vm/cluster/resource pool
  def user_get_tree_node(folder, pid, vat = false)  # Called with folder node, parent tree node id, VM & Templates flag
    kids          = []                            # Return node(s) as an array
    kids_checked  = false
    node = {
      :key         => "#{folder.class.name}_#{folder.id}",
      :title       => folder.name,
      :checkable   => !@edit.nil?,
      :cfmeNoClick => true
    }
    node[:select] = true if @selected_ids.include?(node[:key]) # Check if tag is assigned

    # Handle folder with the name "Datacenters"
    if folder.kind_of?(EmsFolder) && folder.name == "Datacenters"
      folder.folders_only.each do |f|           # Get folders beneath the "Datacenters" folder
        kid_node, kid_checked = user_get_tree_node(f, pid)
        kids += kid_node
        kids_checked ||= kid_checked
      end

      folder.datacenters_only.each do |f|       # Get datacenters beneath the "Datacenters" folder
        kid_node, kid_checked = user_get_tree_node(f, pid)
        kids += kid_node
        kids_checked ||= kid_checked
      end

    # Handle Datacenter folders
    elsif folder.kind_of?(Datacenter)
      node[:tooltip] = _("Datacenter: %{name}") % {:name => folder.name}
      node[:icon] = ActionController::Base.helpers.image_path("100/datacenter.png")
      if @vat || @rp_only
        node[:hideCheckbox] = true
      end
      dc_kids = []
      folder.folders.each do |f|                # Get folders
        kid_node, kid_checked = user_get_tree_node(f, node[:key])
        dc_kids += kid_node
        kids_checked ||= kid_checked
      end
      folder.clusters.each do |c|               # Get the cluster nodes
        kid_node, kid_checked = user_get_tree_node(c, node[:key])
        dc_kids += kid_node
        kids_checked ||= kid_checked
      end
      node[:children] = dc_kids unless dc_kids.empty?
      node[:expand] = true if kids_checked
      kids.push(node)

    # Handle folder named "host" under a Datacenter
    elsif folder.kind_of?(EmsFolder) && folder.name == "host" &&
          folder.parent.kind_of?(Datacenter)
      unless @vat                                 # Skip if doing VMs & Templates
        folder.folders_only.each do |f|           # Get all the folder children
          kid_node, kid_checked = user_get_tree_node(f, pid)
          kids += kid_node
          kids_checked ||= kid_checked
        end
        folder.clusters.each do |c|               # Get all the cluster children
          kid_node, kid_checked = user_get_tree_node(c, pid)
          kids += kid_node
          kids_checked ||= kid_checked
        end
        folder.hosts.each do |h|                  # Get hosts
          kid_node, kid_checked = user_get_tree_node(h, pid)
          kids += kid_node
          kids_checked ||= kid_checked
        end
      end

    # Handle folder named "vm" under a Datacenter
    elsif folder.kind_of?(EmsFolder) && folder.name == "vm" &&
          folder.parent.kind_of?(Datacenter)
      if @vat                                     # Only if doing VMs & Templates
        folder.folders_only.each do |f|           # Get all the folder children
          kid_node, kid_checked = user_get_tree_node(f, pid, true)
          kids += kid_node
          kids_checked ||= kid_checked
        end
      end

    # Handle folder named "Discovered Virtual Machine"
    # elsif folder.class == EmsFolder && folder.name == "Discovered Virtual Machine"
    # Commented this out to handle like any other blue folder, for now

    # Handle normal Folders
    elsif folder.kind_of?(EmsFolder)
      node[:tooltip] = _("Folder: %{name}") % {:name => folder.name}
      if vat
        node[:icon] = ActionController::Base.helpers.image_path("100/blue_folder.png")
      else
        node[:icon] = ActionController::Base.helpers.image_path("100/folder.png")
        if @vat || @rp_only
          node[:hideCheckbox] = true
        end
      end
      f_kids = []
      folder.folders_only.each do |f|           # Get other folders
        kid_node, kid_checked = user_get_tree_node(f, node[:key], vat)
        f_kids += kid_node
        kids_checked ||= kid_checked
      end
      folder.datacenters_only.each do |d|       # Get datacenters
        kid_node, kid_checked = user_get_tree_node(d, node[:key])
        f_kids += kid_node
        kids_checked ||= kid_checked
      end
      folder.clusters.each do |c|               # Get the cluster nodes
        kid_node, kid_checked = user_get_tree_node(c, node[:key])
        f_kids += kid_node
        kids_checked ||= kid_checked
      end
      folder.hosts.each do |h|                  # Get hosts
        kid_node, kid_checked = user_get_tree_node(h, node[:key])
        f_kids += kid_node
        kids_checked ||= kid_checked
      end
      node[:children] = f_kids unless f_kids.empty?
      node[:expand] = true if kids_checked
      kids.push(node)

    # Handle Hosts
    elsif folder.kind_of?(Host) && folder.authorized_for_user?(session[:userid])
      if !@rp_only || (@rp_only && folder.resource_pools.count > 0)
        node[:tooltip] = _("Host: %{name}") % {:name => folder.name}
        if folder.parent_cluster || @rp_only                  # Host is under a cluster, no checkbox
          node[:hideCheckbox] = true
        end
        node[:icon] = ActionController::Base.helpers.image_path("100/host.png")
        h_kids = []
        folder.resource_pools.sort_by { |rp| rp.name.downcase }.each do |rp|
          kid_node, kid_checked = user_get_tree_node(rp, node[:key], vat)
          h_kids += kid_node
          kids_checked ||= kid_checked
        end
        node[:children] = h_kids unless h_kids.empty?
        node[:expand] = true if kids_checked
        kids.push(node)
      end
    # Handle VMs
    elsif folder.kind_of?(Vm) && folder.authorized_for_user?(session[:userid])
    # Do nothing, VMs not shown in filter tree

    # Handle Clusters
    elsif folder.class == EmsCluster
      if !@rp_only || (@rp_only && folder.resource_pools.count > 0)
        node[:tooltip] = _("Cluster: %{name}") % {:name => folder.name}
        node[:icon] = ActionController::Base.helpers.image_path("100/cluster.png")
        node[:hideCheckbox] = true if @vat || @rp_only
        cl_kids = []
        folder.hosts.each do |h|                  # Get hosts
          kid_node, kid_checked = user_get_tree_node(h, node[:key])
          cl_kids += kid_node
          kids_checked ||= kid_checked
        end
        folder.resource_pools.each do |rp|        # Get the resource pool nodes
          kid_node, kid_checked = user_get_tree_node(rp, node[:key])
          cl_kids += kid_node
          kids_checked ||= kid_checked
        end
        node[:children] = cl_kids unless cl_kids.empty?
        node[:expand] = true if kids_checked
        kids.push(node)
      end
    # Handle default Resource Pools
    elsif folder.kind_of?(ResourcePool) && folder.is_default?
      if !@rp_only || (@rp_only && folder.resource_pools.count > 0)
        folder.resource_pools.each do |rp|        # Get all the default resource pool children
          kid_node, kid_checked = user_get_tree_node(rp, pid)
          kids += kid_node
          kids_checked ||= kid_checked
        end
      end

    # Handle non-default Resource Pools
    elsif folder.kind_of?(ResourcePool)         # Resource Pool
      node[:tooltip] = _("Resource Pool: #%{name}") % {:name => folder.name}
      node[:icon] = ActionController::Base.helpers.image_path(folder.vapp ? "100/vapp.png" : "100/resource_pool.png")
      rp_kids = []
      folder.resource_pools.each do |rp|        # Get the resource pool nodes
        kid_node, kid_checked = user_get_tree_node(rp, node[:key])
        rp_kids += kid_node
        kids_checked ||= kid_checked
      end
      node[:children] = rp_kids unless rp_kids.empty?
      node[:expand] = true if kids_checked
      kids.push(node)
    end
    return kids, kids_checked || node[:select] == true
  end

  def parse_nodetype_and_id(x_node)
    x_node.split('_').last.split('-')
  end
end
