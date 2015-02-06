module ApplicationController::TreeSupport
  extend ActiveSupport::Concern

  def squash_toggle
    @record = identify_record(params[:id], controller_name == "host" ? Host : VmOrTemplate)
    item = "h_#{@record.name}"
    render :update do |page|
      if session[:squash_open] == false
        page << "$('#squash_img').prop('src', '/images/toolbars/squashed-all-false.png')"
        page << "$('#squash_img').prop('title', 'Collapse All')"
        page << "cfme_dynatree_toggle_expand('#{j_str(session[:tree_name])}', true)"
        session[:squash_open] = true
      else
        page << "$('#squash_img').prop('src', '/images/toolbars/squashed-all-true.png')"
        page << "$('#squash_img').prop('title', 'Expand All')"
        page << "cfme_dynatree_toggle_expand('#{j_str(session[:tree_name])}', false);"
        page << "cfmeDynatree_activateNodeSilently('#{j_str(session[:tree_name])}', '#{item}');"
        session[:squash_open] = false
      end
    end
  end

  def tree_autoload
    nodes = tree_add_child_nodes(params[:id])
    build_vm_host_array     if !@sb[:tree_hosts].blank? || !@sb[:tree_vms].blank?   #set temp list of hosts/vms to be shown on DC tree on mousein event
    render :update do |page|
      if !@sb[:tree_hosts].blank? || !@sb[:tree_vms].blank?
        page.replace("dc_tree_quads_div", :partial=>"layouts/dc_tree_quads")
      end
      page << "#{j_str(params[:tree])}.loadJSONObject(#{nodes.to_json});"
      if @sb[:node_tooltip] && @sb[:node_text]
        page << "#{j_str(params[:tree])}.setItemText('#{j_str(params[:id])}', '#{j_str(@sb[:node_text])}', '#{j_str(@sb[:node_tooltip])}');"
      end
      # select an item in tree, when new report is added or a report has been queued to run so the report node is expanded
      # to fix an issue where when newly added report was run, it doesnt go to saved report show screen because that node is not loaded yet in the tree
      if @sb[:select_node]
        page << "reports_tree.openItem('xx-#{@sb[:rpt_menu].length-1}_xx-#{@sb[:rpt_menu].length-1}-0');"
        page << "reports_tree.selectItem('#{j_str(x_node)}');"
      end
      # expand indexes folder as well when a table name is clicked in the vmdb_tree, in Database accordion
      if params[:tree] == "vmdb_tree" && @sb[:auto_select_node]
        page << "#{j_str(params[:tree])}.openItem('#{j_str(@sb[:auto_select_node])}');"
      end
      page << "if (typeof #{j_str(params[:tree])} != 'undefined'){#{j_str(params[:tree])}.saveOpenStates('#{j_str(params[:tree])}','path=/');};"
    end
  end

  def tree_autoload_dynatree
    @edit ||= session[:edit]  # Remember any previous @edit
    klass_name = x_tree[:klass_name] if x_active_tree
    nodes = klass_name ? TreeBuilder.tree_add_child_nodes(@sb, klass_name, params[:id]) :
        tree_add_child_nodes(params[:id])
    render :update do |page|
      page << nodes.to_json
    end
  end

  def tree_autoload_quads
    # set temp list of hosts/vms to be shown on DC tree on mousein event
    build_vm_host_array if !@sb[:tree_hosts].blank? || !@sb[:tree_vms].blank?
    render :update do |page|
      if !@sb[:tree_hosts].blank? || !@sb[:tree_vms].blank?
        page.replace("dc_tree_quads_div", :partial => "layouts/dc_tree_quads")
      end
      page << "miqSparkle(false);"
    end
  end

  private ############################

  # Build a compliance history tree
  def compliance_history_tree(rec, count)
    t_kids = Array.new                          # Array to hold node children
    rec.compliances.all(:limit=>count, :order=>"timestamp DESC").each do |c|
      c_node = TreeNodeBuilder.generic_tree_node(
          "c_#{c.id}",
          format_timezone(c.timestamp, Time.zone, 'gtl'),
          "#{c.compliant ? "check" : "x"}.png",
          nil,
          {:style_class => "cfme-no-cursor-node"}
      )
      c_node[:title] = "<b>Compliance Check on:</b> #{c_node[:title]}"
      c_kids = []
      temp_pol_id = nil
      p_node = {}
      p_kids = []
      c.compliance_details.all(:order=>"miq_policy_desc, condition_desc").each do |d|
        if d.miq_policy_id != temp_pol_id
          unless p_node.empty?
            p_node[:children] = p_kids unless p_kids.empty?
            c_kids.push(p_node) if p_node[:children]   # Add policy node to compliance node, if any conditions in policy
          end
          temp_pol_id = d.miq_policy_id
          p_node = TreeNodeBuilder.generic_tree_node(
            "#{c_node[:key]}-p_#{d.miq_policy_id}",
            d.miq_policy_desc,
            "#{d.miq_policy_result ? "check" : "x"}.png",
            nil,
            {:style_class => "cfme-no-cursor-node"}
          )
          p_node[:title] = "<b>Policy:</b> #{p_node[:title]}"
          p_kids = []
        end
        cn_node = TreeNodeBuilder.generic_tree_node(
          "#{p_node[:key]}-cn_#{d.condition_id}",
          d.condition_desc,
          "#{d.condition_result ? "check" : "x"}.png",
          nil,
          {:style_class => "cfme-no-cursor-node"}
        )
        cn_node[:title] = "<b>Condition:</b> #{cn_node[:title]}"
        p_kids.push(cn_node)
      end
      p_node[:children] = p_kids unless p_kids.empty?            # Gather up last policy kids
      c_kids.push(p_node) if p_node[:children]                   # Add last policy node to compliance node
      c_node[:children] = c_kids unless c_kids.empty?
      if c_kids.empty?
        np_node = generic_tree_node(
          "#{c_node[:key]}-nopol",
          "No Compliance Policies Found",
          "#{c_node[:key]}-nopol",
          nil,
          {:style_class => "cfme-no-cursor-node"}
        )
        c_node[:children] = [np_node]
      end
      t_kids.push(c_node)                                     # Add compliance node to tree kids
    end
    t_kids
  end

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
    MiqPolicySet.all.sort_by{|profile| profile.description.downcase}.each do |profile|
      policy_profile_node = TreeNodeBuilder.generic_tree_node(
          "policy_profile_#{profile.id}",
          profile.description,
          "policy_profile#{profile.active? ? "" : "_inactive"}.png",
          nil,
          {:style_class => "cfme-no-cursor-node"}
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
    profile.members.sort_by{|policy| [policy.towhat, policy.mode, policy.description.downcase]}.each do |policy|
      policy_node = TreeNodeBuilder.generic_tree_node(
          "policy_#{policy.id}",
          policy.description,
          "miq_policy_#{policy.towhat.downcase}#{policy.active ? "" : "_inactive"}.png",
          nil,
          {:style_class  => "cfme-no-cursor-node",
           :hideCheckbox => true
          }
      )
      policy_node[:title] = "<b>#{ui_lookup(:model => policy.towhat)} #{policy.mode.capitalize}:</b> #{policy_node[:title]}"
      policy_profile_children.push(policy_node)
    end
    policy_profile_children
  end

  # Return datacenter tree node(s) for the passed in folder/datacenter/host/vm/cluster/resource pool
  def get_dc_node(folder, pid, vat=false)       # Called with folder node, parent tree node id, VM & Templates flag
    @temp[:tree_vms]   ||= []
    @temp[:tree_hosts] ||= []
    @sb[:vat] = vat
    kids = []                            # Return node(s) as an array
    # Handle folder with the name "Datacenters"
    if folder.kind_of?(EmsFolder) && folder.name == "Datacenters"
      folder.folders_only.each do |f|           # Get folders beneath the "Datacenters" folder
        kids += get_dc_node(f, pid, vat)
      end
      folder.datacenters_only.each do |f|       # Get datacenters beneath the "Datacenters" folder
        kids += get_dc_node(f, pid, vat)
      end
    # Handle Datacenter folders
    elsif folder.kind_of?(EmsFolder) && folder.is_datacenter
      # Build the datacenter node
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_dc-#{to_cid(folder.id)}",
        folder.name,
        "datacenter.png",
        "Datacenter: #{folder.name}",
        :style_class   => "cfme-no-cursor-node"
      )
      dc_kids = []
      if @sb[:open_tree_nodes].include?(node[:key])               # If not open, set child flag
        folder.folders.each do |f|                                # Get folders
          dc_kids += get_dc_node(f, node[:key], vat)
        end
        folder.clusters.each do |c|                               # Get the cluster nodes
          dc_kids += get_dc_node(c, node[:key], vat)
        end
      else
        node[:isLazy] = true if folder.folders.size > 0 ||
          folder.clusters.size > 0
      end
      node[:children] = dc_kids unless dc_kids.empty?
      kids.push(node)

    # Handle folder named "host" under a Datacenter
    elsif folder.kind_of?(EmsFolder) && folder.name == "host" &&
          folder.parent.kind_of?(EmsFolder) && folder.parent.is_datacenter
      unless vat                          # Skip if doing VMs & Templates
        folder.folders_only.each do |f|           # Get all the folder children
          kids += get_dc_node(f, pid, vat)
        end
        folder.clusters.each do |c|               # Get all the cluster children
          kids += get_dc_node(c, pid, vat)
        end
        folder.hosts.each do |h|                  # Get hosts
          kids += get_dc_node(h, pid, vat)
        end
      end

    # Handle folder named "vm" under a Datacenter
    elsif folder.kind_of?(EmsFolder) && folder.name == "vm" &&
          folder.parent.kind_of?(EmsFolder) && folder.parent.is_datacenter
      if vat                              # Only if doing VMs & Templates
        folder.folders_only.each do |f|           # Get all the folder children
          kids += get_dc_node(f, pid, vat)
        end
        folder.vms.each do |v|                    # Get VMs
          kids += get_dc_node(v, pid, vat)
        end
      end

    # Handle folder named "Discovered Virtual Machine"
    #elsif folder.kind_of?(EmsFolder) && folder.name == "Discovered Virtual Machine"
    # Commented this out to handle like any other blue folder, for now

    # Handle normal Folders
    elsif folder.kind_of?(EmsFolder)
      # Build the folder node
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_f-#{to_cid(folder.id)}",
        folder.name,
        vat ? "blue_folder.png" : "folder.png",
        "Folder: #{folder.name}",
        :style_class   => "cfme-no-cursor-node"
      )
      f_kids = Array.new
      if @sb[:open_tree_nodes].include?(node[:key]) # If not open, set child flag
        folder.folders_only.each do |f|           # Get other folders
          f_kids += get_dc_node(f, node[:key], vat)
        end
        folder.datacenters_only.each do |d|       # Get datacenters
          f_kids += get_dc_node(d, node[:key], vat)
        end
        folder.clusters.each do |c|               # Get the cluster nodes
          f_kids += get_dc_node(c, node[:key], vat)
        end
        folder.hosts.each do |h|                  # Get hosts
          f_kids += get_dc_node(h, node[:key], vat)
        end
        folder.vms.each do |v|                    # Get VMs
          f_kids += get_dc_node(v, node[:key], vat)
        end
      else
        node[:isLazy] = true if folder.folders_only.count > 0 ||
          folder.datacenters_only.count > 0 || folder.clusters.count > 0 ||
          folder.vms.count > 0 || folder.hosts.count > 0
      end
      node[:children] = f_kids unless f_kids.empty?
      kids.push(node)

    # Handle Hosts
    elsif folder.kind_of?(Host) && folder.authorized_for_user?(session[:userid])
      @sb[:tree_hosts].push(folder.id) unless @sb[:tree_hosts].include?(folder.id)
      # Build the host node
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_h-#{to_cid(folder.id)}",
        folder.name,
        "host.png",
        "Host: #{folder.name}",
        :style_class   => "cfme-no-cursor-node"
      )
      h_kids = []
      if @sb[:open_tree_nodes].include?(node[:key]) # If not open, set child flag
        folder.resource_pools.each do |rp|
          h_kids += get_dc_node(rp, node[:key], vat)
        end
        if folder.default_resource_pool           # Go thru default RP VMs
          folder.default_resource_pool.vms.each do |v|
            h_kids += get_dc_node(v, node[:key], vat)
          end
        end
      else
        set_node_tooltip_and_is_lazy(node,
                                     "Host: #{folder.name} (click to view)",
                                     folder.resource_pools.count > 0 ||
                                       (folder.default_resource_pool &&
                                         folder.default_resource_pool.vms.count > 0)
        )
      end
      node[:children] = h_kids unless h_kids.empty?
      kids.push(node)

    # Handle VMs
    elsif folder.kind_of?(Vm) && folder.authorized_for_user?(session[:userid])
      @sb[:tree_vms].push(folder.id) unless @sb[:tree_vms].include?(folder.id)
      # Build the VM node
      if folder.template?
        if folder.host
          image = "template.png"
        else
          image = "template-no-host.png"
        end
      else
        image = "#{folder.current_state.downcase}.png"
      end
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_v-#{to_cid(folder.id)}",
        folder.name,
        image,
        "VM: #{folder.name} (Click to view)",
        :style_class   => "cfme-no-cursor-node"
      )
      kids.push(node)

    # Handle Clusters
    elsif folder.kind_of?(EmsCluster)
      # Build the cluster node
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_c-#{to_cid(folder.id)}",
        folder.name,
        "cluster.png",
        "VM: #{folder.name} (Click to view)",
        :style_class   => "cfme-no-cursor-node"
      )
      cl_kids = Array.new
      if @sb[:open_tree_nodes].include?(node[:key]) # If not open, set child flag
        folder.hosts.each do |h|                  # Get hosts
          cl_kids += get_dc_node(h, node[:key], vat)
        end
        folder.resource_pools.each do |rp|        # Get the resource pool nodes
          cl_kids += get_dc_node(rp, node[:key], vat)
        end
        folder.vms.each do |v|                    # Get VMs
          cl_kids += get_dc_node(v, pid, vat)
        end
      else
        set_node_tooltip_and_is_lazy(node,
                                     "Cluster: #{folder.name} (Click to view)",
                                     folder.resource_pools.count > 0 ||
                                       folder.vms.count > 0 ||
                                       folder.hosts.count > 0
        )
      end
      node[:children] = cl_kids unless cl_kids.empty?
      kids.push(node)

    # Handle Resource Pools with no name (default, don't show them) or "Resources" for default
    # Cluster Resource Pools in VC 3.5
    elsif folder.kind_of?(ResourcePool) && folder.is_default
      folder.resource_pools.each do |rp|        # Get all the resource pool children
        kids += get_dc_node(rp, pid, vat)
      end
      folder.vms.each do |v|                    # Get VMs
        kids += get_dc_node(v, pid, vat)
      end

    # Handle non-default Resource Pools
    elsif folder.kind_of?(ResourcePool)         # Resource Pool
      f_name = folder.name.gsub(/'/,"&apos;")
      node = TreeNodeBuilder.generic_tree_node(
        "#{pid}_rp-#{to_cid(folder.id)}",
        f_name,
        folder.vapp ? "vapp.png" : "resource_pool.png",
        nil,
        :style_class   => "cfme-no-cursor-node"
      )
      rp_kids = []
      if @sb[:open_tree_nodes].include?(node[:key]) # If not open, set child flag
        folder.resource_pools.each do |rp|        # Get the resource pool nodes
          rp_kids += get_dc_node(rp, node[:key], vat)
        end
        folder.vms.each do |v|                    # Get VMs
          rp_kids += get_dc_node(v, node[:key], vat)
        end
      else
        set_node_tooltip_and_is_lazy(node,
                                     "Resource Pool: #{f_name} (Click to view)",
                                     folder.resource_pools.count > 0 || folder.vms.count > 0
        )
      end
      node[:children] = rp_kids unless rp_kids.empty?
      kids.push(node)
    end
    # build vms/hosts array on initial load incase vms/hosts are being shown on initial display
    build_vm_host_array if %w{show treesize}.include?(params[:action])
    return kids
  end

  def set_node_tooltip_and_is_lazy(node, tooltip, children)
    node[:isLazy] = true if children
    node[:tooltip] = tooltip
  end

  DC_NODES = {
    "dc" => "EmsFolder",
    "c"  => "EmsCluster",
    "f"  => "EmsFolder",
    "h"  => "Host",
    "rp" => "ResourcePool",
    "v"  => "Vm"
  }

  # Add the children of a node that is being expanded (autoloaded)
  def get_dc_child_nodes(id)
    vat = (params[:tree] == "vt_tree")
    @sb[:last_selected] = id
    nodes = id.split("_").last.split('-')                       # Get all the nodes from the incoming id
    model = DC_NODES[nodes[0]]                            # Get this nodes model (folder, Vm, Cluster, etc)
    folder = model.constantize.find(from_cid(nodes[1]))
    @sb[:open_tree_nodes].push(id) unless @sb[:open_tree_nodes].include?(id) # Save node as open
    t_kids = []                          # Array to hold node children
    case nodes[0]
    when "dc" # Datacenter
      if folder.kind_of?(EmsFolder) && folder.is_datacenter
        folder.folders.each do |f|                # Get folders
          n_node = get_dc_node(f, id, vat)
          t_kids += n_node
        end
        folder.clusters.each do |c|               # Get the cluster nodes
          n_node = get_dc_node(c, id, vat)
          t_kids += n_node
        end
      end
    when "f"  # Folder
      folder.folders_only.each do |f|           # Get other folders
        n_node = get_dc_node(f, id, vat)
        t_kids += n_node
      end
      folder.datacenters_only.each do |d|       # Get datacenters
        n_node = get_dc_node(d, id, vat)
          t_kids += n_node
      end
      folder.clusters.each do |c|               # Get the cluster nodes
        n_node = get_dc_node(c, id, vat)
          t_kids += n_node
      end
      folder.hosts.each do |h|                  # Get hosts
        n_node = get_dc_node(h, id, vat)
        t_kids += n_node
      end
      folder.vms.each do |v|                    # Get VMs
        n_node = get_dc_node(v, id, vat)
        t_kids += n_node
      end
    when "rp" # ResourcePool
      f_name = folder.name.gsub(/'/,"&apos;")
      @sb[:node_text] = f_name
      @sb[:node_tooltip] = "Resource Pool: #{f_name} (Click to view)"
      folder.resource_pools.each do |rp|        # Get the resource pool nodes
        n_node = get_dc_node(rp, id, vat)
        t_kids += n_node
      end
      folder.vms.each do |v|                    # Get VMs
        n_node = get_dc_node(v, id, vat)
        t_kids += n_node
      end
    when "c"  # EmsCluster
      @sb[:node_text] = folder.name
      @sb[:node_tooltip] = "Cluster: #{folder.name} (Click to view)"
      folder.hosts.each do |h|                  # Get hosts
        n_node = get_dc_node(h, id, vat)
        t_kids += n_node
      end
      folder.resource_pools.each do |rp|        # Get the resource pool nodes
        n_node = get_dc_node(rp, id, vat)
        t_kids += n_node
      end
      folder.vms.each do |v|                    # Get VMs
        n_node = get_dc_node(v, id, vat)
        t_kids += n_node
      end
    when "h"  # Host
      @sb[:node_text] = folder.name
      @sb[:node_tooltip] = "Host: #{folder.name} (Click to view)"
      folder.resource_pools.each do |rp|
        n_node = get_dc_node(rp, id, vat)
        t_kids += n_node
      end
      if folder.default_resource_pool           # Go thru default RP VMs
        folder.default_resource_pool.vms.each do |v|
          n_node = get_dc_node(v, id, vat)
          t_kids += n_node
        end
      end
    when "v"  # Vm
    end
    t_kids
  end

  # Build the H&C or V&T tree with nodes selected
  def build_belongsto_tree(selected_ids, vat = false, save_tree_in_session = true, rp_only = false)
    @selected_ids = selected_ids
    @vat = true if vat
    #for Alert profile assignments where checkboxes are only required on Resource Pools
    @rp_only  = true if rp_only
    providers = []                          # Array to hold all providers
    ExtManagementSystem.all.each do |ems| # Go thru all of the providers
      if !@rp_only || (@rp_only && ems.resource_pools.count > 0)
        ems_node = {
          :key        => "#{ems.class.name}_#{ems.id}",
          :title      => ems.name,
          :tooltip    => "#{ui_lookup(:table=>"ems_infras")}: #{ems.name}",
          :addClass   => "cfme-no-cursor-node",      # No cursor pointer
          :icon       => "ems.png"
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
  def user_get_tree_node(folder, pid, vat=false)  # Called with folder node, parent tree node id, VM & Templates flag
    kids          = []                            # Return node(s) as an array
    kids_checked  = false
    node = {
      :key    => "#{folder.class.name}_#{folder.id}",
      :title  => folder.name
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
    elsif folder.kind_of?(EmsFolder) && folder.is_datacenter
      node[:tooltip] = "Datacenter: #{folder.name}"
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      node[:icon] = "datacenter.png"
      if @vat || @rp_only
        node[:hideCheckbox] = true
      else
        # Check for @edit as alert profile assignment uses this method, but uses @assign object
        if @edit &&
          @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
      end
      dc_kids = Array.new
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
          folder.parent.kind_of?(EmsFolder) && folder.parent.is_datacenter
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
          folder.parent.kind_of?(EmsFolder) && folder.parent.is_datacenter
      if @vat                                     # Only if doing VMs & Templates
        folder.folders_only.each do |f|           # Get all the folder children
          kid_node, kid_checked = user_get_tree_node(f, pid, true)
          kids += kid_node
          kids_checked ||= kid_checked
        end
      end

    # Handle folder named "Discovered Virtual Machine"
    #elsif folder.class == EmsFolder && folder.name == "Discovered Virtual Machine"
      # Commented this out to handle like any other blue folder, for now

    # Handle normal Folders
    elsif folder.kind_of?(EmsFolder)
      node[:tooltip] = "Folder: #{folder.name}"
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      if vat
        node[:icon] = "blue_folder.png"
        if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
      else
        node[:icon] = "folder.png"
        if @vat || @rp_only
          node[:hideCheckbox] = true
        else
          if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
            node[:addClass] = "cfme-blue-bold-node"  # Show node as different
          end
        end
      end
      f_kids = Array.new
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
        node[:tooltip] = "Host: #{folder.name} (Click to view)"
        node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
        if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
          node[:addClass] = "cfme-blue-bold-node"  # Show node as different
        end
        if folder.parent_cluster || @rp_only                  # Host is under a cluster, no checkbox
          node[:hideCheckbox] = true
        end
        node[:icon] = "host.png"
        h_kids = Array.new
        folder.resource_pools.sort{|a,b|a.name.downcase<=>b.name.downcase}.each do |rp|
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
        node[:tooltip] = "Cluster: #{folder.name}"
        node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
        node[:icon] = "cluster.png"
        node[:hideCheckbox] = true if @vat || @rp_only
        node[:addClass] = "cfme-blue-bold-node" if @edit &&
          @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]
        cl_kids = Array.new
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
      node[:tooltip] = "Resource Pool: #{folder.name}"
      node[:addClass] = "cfme-no-cursor-node"          # No cursor pointer
      if @edit && @edit[:new][:belongsto][node[:key]] != @edit[:current][:belongsto][node[:key]]  # Check new vs current
        node[:addClass] = "cfme-blue-bold-node"  # Show node as different
      end
      node[:icon] = folder.vapp ? "vapp.png" : "resource_pool.png"
      rp_kids = Array.new
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
