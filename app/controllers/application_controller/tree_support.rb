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
        page << "miqDynatreeToggleExpand('#{j_str(session[:tree_name])}', true)"
        session[:squash_open] = true
      else
        page << "$('#squash_img i').attr('class','fa fa-angle-double-down fa-lg')"
        page << "$('#squash_img').prop('title', 'Expand All')"
        page << "miqDynatreeToggleExpand('#{j_str(session[:tree_name])}', false);"
        page << "miqDynatreeActivateNodeSilently('#{j_str(session[:tree_name])}', '#{item}');"
        session[:squash_open] = false
      end
    end
  end

  def find_record
    # TODO: This logic should probably be reversed - fixed list for VmOrTemplate.
    # (Better yet, override the method only in VmOrTemplate related controllers.)
    if %w(host container_replicator container_group container_node container_image).include? controller_name
      identify_record(params[:id], controller_name.classify)
    else
      identify_record(params[:id], VmOrTemplate)
    end
  end

  def tree_autoload_dynatree
    @edit ||= session[:edit]  # Remember any previous @edit
    klass_name = x_tree[:klass_name] if x_active_tree
    nodes = klass_name ? TreeBuilder.tree_add_child_nodes(@sb, klass_name, params[:id]) :
        tree_add_child_nodes(params[:id])
    render :json => nodes
  end

  def tree_autoload_quads
    # set temp list of hosts/vms to be shown on DC tree on mousein event
    build_vm_host_array if !@sb[:tree_hosts_hash].blank? || !@sb[:tree_vms_hash].blank?
    render :update do |page|
      page << javascript_prologue
      if !@sb[:tree_hosts_hash].blank? || !@sb[:tree_vms_hash].blank?
        page.replace("dc_tree_quads_div", :partial => "layouts/dc_tree_quads")
      end
      page << "miqSparkle(false);"
    end
  end

  private ############################

  # Build the manage policies tree
  def protect_build_tree
    @sb[:no_policy_profiles] = false
    policy_profiles = policy_profile_nodes
    session[:policy_tree] = policy_profiles.to_json
    @sb[:no_policy_profiles] = true if policy_profiles.blank?
    session[:tree_name] = "protect_tree"
  end

  def policy_profile_nodes
    profiles = []
    MiqPolicySet.all.sort_by { |profile| profile.description.downcase }.each do |profile|
      policy_profile_node = TreeNodeBuilder.generic_tree_node(
        "policy_profile_#{profile.id}",
        profile.description,
        "policy_profile#{profile.active? ? "" : "_inactive"}.png",
        nil,
        :style_class => "cfme-no-cursor-node"
      )
      unless @edit[:new][profile.id] == 0              # If some have this policy: set check if all, set mixed check if some
        policy_profile_node[:select] = true if @edit[:new][profile.id] == session[:pol_items].length
        policy_profile_node[:title]  = "* #{policy_profile_node[:title]}" unless @edit[:new][profile.id] == session[:pol_items].length
      end
      if @edit[:new][profile.id] != @edit[:current][profile.id]
        policy_profile_node[:addClass] = "cfme-blue-bold-node"
      end
      policy_profile_node[:children] = policy_profile_branch_nodes(profile) if profile.members.length > 0
      profiles.push(policy_profile_node)
    end
    profiles
  end

  def policy_profile_branch_nodes(profile)
    policy_profile_children = []
    profile.members.sort_by { |policy| [policy.towhat, policy.mode, policy.description.downcase] }.each do |policy|
      policy_node = TreeNodeBuilder.generic_tree_node(
        "policy_#{policy.id}",
        policy.description,
        "miq_policy_#{policy.towhat.downcase}#{policy.active ? "" : "_inactive"}.png",
        nil,
        :style_class  => "cfme-no-cursor-node",
        :hideCheckbox => true
      )
      policy_node[:title] = "<b>#{ui_lookup(:model => policy.towhat)} #{policy.mode.capitalize}:</b> #{policy_node[:title]}"
      policy_profile_children.push(policy_node)
    end
    policy_profile_children
  end

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
          :key      => "#{ems.class.name}_#{ems.id}",
          :title    => ems.name,
          :tooltip  => "#{ui_lookup(:table => "ems_infras")}: #{ems.name}",
          :addClass => "cfme-no-cursor-node",      # No cursor pointer
          :icon     => ActionController::Base.helpers.image_path("svg/vendor-#{ems.image_name}.svg")
        }
        if @vat || @rp_only
          ems_node[:hideCheckbox] = true
        else
          if @edit &&
             @edit[:new][:belongsto][ems_node[:key]] != @edit[:current][:belongsto][ems_node[:key]]
            ems_node[:addClass] = "cfme-blue-bold-node"  # Show node as different
          end
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
      session["#{session[:tree]}_tree".to_sym] = providers.to_json  # Add ems node array to root of tree
    else
      providers.to_json  # Return tree nodes to the caller
    end
  end

  # Return tree node(s) for the passed in folder/datacenter/host/vm/cluster/resource pool
  def user_get_tree_node(folder, pid, vat = false)  # Called with folder node, parent tree node id, VM & Templates flag
    kids          = []                            # Return node(s) as an array
    kids_checked  = false
    node = {
      :key   => "#{folder.class.name}_#{folder.id}",
      :title => folder.name
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
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      node[:icon] = ActionController::Base.helpers.image_path("100/datacenter.png")
      if @vat || @rp_only
        node[:hideCheckbox] = true
      else
        # Check for @edit as alert profile assignment uses this method, but uses @assign object
        if @edit &&
           @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
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
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      if vat
        node[:icon] = ActionController::Base.helpers.image_path("100/blue_folder.png")
        if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
      else
        node[:icon] = ActionController::Base.helpers.image_path("100/folder.png")
        if @vat || @rp_only
          node[:hideCheckbox] = true
        else
          if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
            node[:addClass] = "cfme-blue-bold-node"  # Show node as different
          end
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
        node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
        if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
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
        node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
        node[:icon] = ActionController::Base.helpers.image_path("100/cluster.png")
        node[:hideCheckbox] = true if @vat || @rp_only
        node[:addClass] = "cfme-blue-bold-node" if @edit &&
                                                   @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]
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
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
        node[:addClass] = "cfme-blue-bold-node"  # Show node as different
      end
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
end
