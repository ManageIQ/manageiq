module VmCommon
  extend ActiveSupport::Concern

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:page] = @current_page if @current_page != nil   # Save current page for list refresh
    @refresh_div = "main_div" # Default div for button.rjs to refresh

    custom_buttons                if params[:pressed] == "custom_button"
    perf_chart_chooser            if params[:pressed] == "perf_reload"
    perf_refresh_data             if params[:pressed] == "perf_refresh"
    remove_service                if params[:pressed] == "remove_service"

    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
    # VM sub-screen is showing, so return
    return if ["perf_reload"].include?(params[:pressed]) && @flash_array == nil

    if @flash_array == nil # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    else    # Figure out what was showing to refresh it
      if @lastaction == "show" && ["vmtree"].include?(@showtype)
        @refresh_partial = @showtype
      elsif @lastaction == "show" && ["config"].include?(@showtype)
        @refresh_partial = @showtype
      elsif @lastaction == "show_list"
        # default to the gtl_type already set
      else
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      end
    end
    @vm = @record = identify_record(params[:id], VmOrTemplate) unless @lastaction == "show_list"

    if !@flash_array.nil? && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit")
      if @redirect_controller
        render :update do |page|
          page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :org_controller=>@org_controller
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        if @refresh_div == "flash_msg_div"
          render :partial => "shared/ajax/flash_msg_replace"
        else
          options
          partial_replace(@refresh_div, "vm_common/#{@refresh_partial}")
        end
      end
    end
  end

  def show_timeline
    db = get_rec_cls
    @display = "timeline"
    session[:tl_record_id] = params[:id] if params[:id]
    @record = find_by_id_filtered(db, from_cid(session[:tl_record_id]))
    @timeline = @timeline_filter = true
    @lastaction = "show_timeline"
    tl_build_timeline                       # Create the timeline report
    drop_breadcrumb( {:name=>"Timelines", :url=>"/#{db}/show_timeline/#{@record.id}?refresh=n"} )
    if @explorer
      @refresh_partial = "layouts/tl_show"
      if params[:refresh]
        @sb[:action] = "timeline"
        replace_right_cell
      end
    end
  end
  alias image_timeline show_timeline
  alias instance_timeline show_timeline
  alias vm_timeline show_timeline
  alias miq_template_timeline show_timeline

  # Launch a VM console
  def console
    console_type = get_vmdb_config.fetch_path(:server, :remote_console_type).downcase
    params[:task_id] ? console_after_task(console_type) : console_before_task(console_type)
  end
  alias vmrc_console console  # VMRC needs its own URL for RBAC checking

  def html5_console
    params[:task_id] ? console_after_task('html5') : console_before_task('html5')
  end

  def launch_vmware_console
    console_type = get_vmdb_config.fetch_path(:server, :remote_console_type).downcase
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    options = case console_type
              when "mks"
                @sb[:mks].update(
                  'version' => get_vmdb_config[:server][:mks_version]
                )
              when "vmrc"
                {
                  :host        => @record.ext_management_system.ipaddress ||
                                  @record.ext_management_system.hostname,
                  :vmid        => @record.ems_ref,
                  :ticket      => @sb[:vmrc_ticket],
                  :api_version => @record.ext_management_system.api_version.to_s,
                  :os          => browser_info(:os).downcase,
                  :name        => @record.name
                }
              end
    render :template => "vm_common/console_#{console_type}",
           :layout   => false,
           :locals   => options
  end

  def launch_html5_console
    password, host_address, host_port, _proxy_address, _proxy_port, protocol, ssl = @sb[:html5]
    encrypt = get_vmdb_config.fetch_path(:server, :websocket_encrypt)

    proxy_options = WsProxy.start(
      :host       => host_address,
      :host_port  => host_port,
      :password   => password,
      :ssl_target => ssl,       # ssl on provider side
      :encrypt    => encrypt    # ssl on web client side
    )
    raise _("Console access failed: proxy errror") if proxy_options.nil?

    view = case protocol   # spice, vnc - from rhevm
           when 'spice'
             "vm_common/console_spice"
           when nil, 'vnc' # nil - from vmware
             "vm_common/console_vnc"
           end

    render :template => view,
           :layout   => false,
           :locals   => proxy_options
  end

  # VM clicked on in the explorer right cell
  def x_show
    @explorer = true
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    respond_to do |format|
      format.js do                  # AJAX, select the node
        unless @record
          redirect_to :action => "explorer"
          return
        end
        params[:id] = x_build_node_id(@record)  # Get the tree node id
        tree_select
      end
      format.html do                # HTML, redirect to explorer
        tree_node_id = TreeBuilder.build_node_id(@record)
        session[:exp_parms] = {:id => tree_node_id}
        redirect_to :action => "explorer"
      end
      format.any {render :nothing=>true, :status=>404}  # Anything else, just send 404
    end
  end

  def show(id = nil)
    @flash_array = [] if params[:display]
    @sb[:action] = params[:display]

    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?
    @display = params[:vm_tree] if params[:vm_tree]

    @lastaction = "show"
    @showtype = "config"
    @record = identify_record(id || params[:id], VmOrTemplate)
    return if record_no_longer_exists?(@record)

    @explorer = true if request.xml_http_request? # Ajax request means in explorer

    if !@explorer && @display != "download_pdf"
      tree_node_id = TreeBuilder.build_node_id(@record)
      session[:exp_parms] = {:display => @display, :refresh => params[:refresh], :id => tree_node_id}
      redirect_to :controller => controller_for_vm(model_for_vm(@record)),
                  :action     => "explorer"
      return
    end

    if @record.class.base_model.to_s == "MiqTemplate"
      rec_cls = @record.class.base_model.to_s.underscore
    else
      rec_cls = "vm"
    end
    @gtl_url = "/#{rec_cls}/show/" << @record.id.to_s << "?"
    if ["download_pdf","main","summary_only"].include?(@display)
      get_tagdata(@record)
      drop_breadcrumb({:name=>"Virtual Machines", :url=>"/#{rec_cls}/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( {:name=>@record.name + " (Summary)", :url=>"/#{rec_cls}/show/#{@record.id}"} )
      @showtype = "main"
      @button_group = "#{rec_cls}"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    elsif @display == "networks"
      drop_breadcrumb( {:name=>@record.name+" (Networks)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
    elsif @display == "os_info"
      drop_breadcrumb( {:name=>@record.name+" (OS Information)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
    elsif @display == "hv_info"
      drop_breadcrumb( {:name=>@record.name+" (Container)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
    elsif @display == "resources_info"
      drop_breadcrumb( {:name=>@record.name+" (Resources)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
    elsif @display == "snapshot_info"
      drop_breadcrumb( {:name=>@record.name+" (Snapshots)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
      build_snapshot_tree
      @button_group = "snapshot"
    elsif @display == "miq_proxies"
      drop_breadcrumb({:name=>"Virtual Machines", :url=>"/#{rec_cls}/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( {:name=>@record.name+" (Managing SmartProxies)", :url=>"/#{rec_cls}/show/#{@record.id}?display=miq_proxies"} )
      @view, @pages = get_view(MiqProxy, :parent=>@record)  # Get the records (into a view) and the paginator
      @showtype = "miq_proxies"
      @gtl_url = "/#{rec_cls}/show/" << @record.id.to_s << "?"

    elsif @display == "vmtree_info"
      @tree_vms = Array.new                     # Capture all VM ids in the tree
      drop_breadcrumb( {:name=>@record.name, :url=>"/#{rec_cls}/show/#{@record.id}"}, true )
      drop_breadcrumb( {:name=>@record.name+" (Genealogy)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
      #session[:base_id] = @record.id
      vmtree_nodes = vmtree(@record)
      @temp[:vm_tree] = vmtree_nodes.to_json
      @temp[:tree_name] = "genealogy_tree"
      @button_group = "vmtree"
    elsif @display == "compliance_history"
      count = params[:count] ? params[:count].to_i : 10
      session[:ch_tree] = compliance_history_tree(@record, count).to_json
      session[:tree_name] = "ch_tree"
      session[:squash_open] = (count == 1)
      drop_breadcrumb( {:name=>@record.name, :url=>"/#{rec_cls}/show/#{@record.id}"}, true )
      if count == 1
        drop_breadcrumb( {:name=>@record.name+" (Latest Compliance Check)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
      else
        drop_breadcrumb( {:name=>@record.name+" (Compliance History - Last #{count} Checks)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
      end
      @showtype = @display
    elsif @display == "performance"
      @showtype = "performance"
      drop_breadcrumb( {:name=>"#{@record.name} Capacity & Utilization", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}&refresh=n"} )
      perf_gen_init_options               # Initialize perf chart options, charts will be generated async
    elsif @display == "disks"
      @showtype = "disks"
      disks
      drop_breadcrumb( {:name=>"#{@record.name} (Disks)", :url=>"/#{rec_cls}/show/#{@record.id}?display=#{@display}"} )
    elsif @display == "ontap_logical_disks"
      drop_breadcrumb( {:name=>@record.name+" (All #{ui_lookup(:tables=>"ontap_logical_disk")})", :url=>"/#{rec_cls}/show/#{@record.id}?display=ontap_logical_disks"} )
      @view, @pages = get_view(OntapLogicalDisk, :parent=>@record, :parent_method => :logical_disks)  # Get the records (into a view) and the paginator
      @showtype = "ontap_logical_disks"
    elsif @display == "ontap_storage_systems"
      drop_breadcrumb( {:name=>@record.name+" (All #{ui_lookup(:tables=>"ontap_storage_system")})", :url=>"/#{rec_cls}/show/#{@record.id}?display=ontap_storage_systems"} )
      @view, @pages = get_view(OntapStorageSystem, :parent=>@record, :parent_method => :storage_systems)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_systems"
    elsif @display == "ontap_storage_volumes"
      drop_breadcrumb( {:name=>@record.name+" (All #{ui_lookup(:tables=>"ontap_storage_volume")})", :url=>"/#{rec_cls}/show/#{@record.id}?display=ontap_storage_volumes"} )
      @view, @pages = get_view(OntapStorageVolume, :parent=>@record, :parent_method => :storage_volumes)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"
    elsif @display == "ontap_file_shares"
      drop_breadcrumb( {:name=>@record.name+" (All #{ui_lookup(:tables=>"ontap_file_share")})", :url=>"/#{rec_cls}/show/#{@record.id}?display=ontap_file_shares"} )
      @view, @pages = get_view(OntapFileShare, :parent=>@record, :parent_method => :file_shares)  # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end

    unless @record.hardware.nil?
      @record_notes = @record.hardware.annotation.nil? ? "<No notes have been entered for this VM>" : @record.hardware.annotation
    end
    set_config(@record)
    get_host_for_vm(@record)
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
    if @explorer
#     @in_a_form = true
      @refresh_partial = "layouts/performance"
      replace_right_cell if !["download_pdf","performance"].include?(params[:display])
    end
  end

  def summary_pdf
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?
    @display = params[:vm_tree] if params[:vm_tree]

    @lastaction = "show"
    @showtype   = "config"

    @vm = @record = identify_record(params[:id], VmOrTemplate)
    return if record_no_longer_exists?(@vm)

    rec_cls = "vm"

    @gtl_url = "/#{rec_cls}/show/" << @record.id.to_s << "?"
    get_tagdata(@record)
    drop_breadcrumb({:name=>"Virtual Machines", :url=>"/#{rec_cls}/show_list?page=#{@current_page}&refresh=y"}, true)
    drop_breadcrumb( {:name=>@record.name + " (Summary)", :url=>"/#{rec_cls}/show/#{@record.id}"} )
    @showtype = "main"
    @button_group = "#{rec_cls}"
    @report_only = true
    @showtype = "summary_only"
    @title = @record.name + " (Summary)"
    unless @record.hardware.nil?
      @record_notes = @record.hardware.annotation.nil? ? "<No notes have been entered for this VM>" : @record.hardware.annotation
    end
    set_config(@record)
    get_host_for_vm(@record)
    session[:tl_record_id] = @record.id
    html_string = render_to_string(:template => '/layouts/show_pdf', :layout => false)
    pdf_data = PdfGenerator.pdf_from_string(html_string, 'pdf_summary')
    disable_client_cache
    fname = "#{@record.name}_summary_#{format_timezone(Time.now, Time.zone, "fname")}"
    send_data(pdf_data, :filename => "#{fname}.pdf", :type => "application/pdf" )
  end

  def vmtree(vm)
    session[:base_vm] = "_h-" + vm.id.to_s + "|"
    if vm.parents.length > 0
      vm_parent = vm.parents
      @tree_vms.push(vm_parent[0]) unless @tree_vms.include?(vm_parent[0])
      parent_node = Hash.new
      session[:parent_vm] = "_v-" + vm_parent[0].id.to_s  + "|"       # setting base node id to be passed for check/uncheck all button
      image = ""
      if vm_parent[0].retired == true
        image = "retired.png"
      else
        if vm_parent[0].template?
          if vm_parent[0].host
            image = "template.png"
          else
            image = "template-no-host.png"
          end
        else
          image = "#{vm_parent[0].current_state.downcase}.png"
        end
      end
      parent_node = TreeNodeBuilder.generic_tree_node(
        "_v-#{vm_parent[0].id}|",
        "#{vm_parent[0].name} (Parent)",
        image,
        "VM: #{vm_parent[0].name} (Click to view)",
        )
    else
      session[:parent_vm] = nil
    end

    session[:parent_vm] = session[:base_vm] if session[:parent_vm].nil?  # setting base node id to be passed for check/uncheck all button if vm has no parent

    base = Array.new
    base_node = vm_kidstree(vm)
    base.push(base_node)
    if !parent_node.nil?
      parent_node[:children] = base
      parent_node[:expand] = true
      return parent_node
    else
      base_node[:expand] = true
      return base_node
    end
  end

  # Recursive method to build a snapshot tree node
  def vm_kidstree(vm)
    branch = Hash.new
    key = "_v-#{vm.id}|"
    title = vm.name
    style = ""
    tooltip = "VM: #{vm.name} (Click to view)"
    if session[:base_vm] == "_h-#{vm.id}|"
      title << " (Selected)"
      key = session[:base_vm]
      style = "dynatree-cfme-active cfme-no-cursor-node"
      tooltip = ""
    end
    image = ""
      if vm.template?
        if vm.host
          image = "template.png"
        else
          image = "template-no-host.png"
        end
      else
        image = "#{vm.current_state.downcase}.png"
      end
      branch = TreeNodeBuilder.generic_tree_node(
        key,
        title,
        image,
        tooltip,
        :style_class => style
      )
    @tree_vms.push(vm) unless @tree_vms.include?(vm)
    if vm.children.length > 0
      kids = Array.new
      vm.children.each do |kid|
        kids.push(vm_kidstree(kid)) unless @tree_vms.include?(kid)
      end
      branch[:children] = kids.sort_by { |a| a[:title].downcase }
    end
    return branch
  end

  def build_snapshot_tree
    vms = @record.snapshots.all
    parent = TreeNodeBuilder.generic_tree_node(
      "snaproot",
      @record.name,
      "vm.png",
      nil,
      :cfme_no_click => true,
      :expand        => true,
      :style_class   => "cfme-no-cursor-node"
    )
    @record.snapshots.each do | s |
      if s.current.to_i == 1
        @root   = s.id
        @active = true
      end
    end
    @root = @record.snapshots.first.id if @root.nil? && @record.snapshots.size > 0
    session[:snap_selected] = @root if params[:display] == "snapshot_info"
    @temp[:snap_selected] = Snapshot.find(session[:snap_selected]) unless session[:snap_selected].nil?
    snapshots = Array.new
    vms.each do |snap|
      if snap.parent_id.nil?
        snapshots.push(snaptree(snap))
      end
    end
    parent[:children] = snapshots
    top = @record.snapshots.find_by_parent_id(nil)
    @snaps = [parent].to_json unless top.nil? && parent.blank?
  end

  # Recursive method to build a snapshot nodes
  def snaptree(node)
    branch = TreeNodeBuilder.generic_tree_node(
      node.id,
      node.name,
      "snapshot.png",
      "Click to select",
      :expand => true
    )
    branch[:title] << " (Active)" if node.current?
    branch[:addClass] = "dynatree-cfme-active" if session[:snap_selected].to_s == branch[:key].to_s
    if node.children.count > 0
      kids = Array.new
      node.children.each do |kid|
        kids.push(snaptree(kid))
      end
      branch[:children] = kids
    end
    return branch
  end

  def vmtree_selected
    base = params[:id].split('-')
    base = base[1].slice(0,base[1].length-1)
    session[:base_vm] = "_h-" + base.to_s
    @display = "vmtree_info"
    render :update do |page|                    # Use RJS to update the display
      page.redirect_to :action=>"show", :id=>base,:vm_tree=>"vmtree_info"
    end
  end

  def snap_pressed
    session[:snap_selected] = params[:id]
    @temp[:snap_selected] = Snapshot.find_by_id(session[:snap_selected])
    @vm = @record = identify_record(x_node.split('-').last, VmOrTemplate)
    if @temp[:snap_selected].nil?
      @display = "snapshot_info"
      add_flash(_("Last selected %s no longer exists") %  "Snapshot", :error)
    end
    build_snapshot_tree
    @active = @temp[:snap_selected].current.to_i == 1 if @temp[:snap_selected]
    @button_group = "snapshot"
    @explorer = true
    c_buttons, c_xml = build_toolbar_buttons_and_xml("x_vm_center_tb")
    render :update do |page|                    # Use RJS to update the display
      if c_buttons && c_xml
        page << "dhxLayoutB.cells('a').expand();"
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << javascript_show_if_exists("center_buttons_div")
      else
        page << javascript_hide_if_exists("center_buttons_div")
      end

      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace("desc_content", :partial => "/vm_common/snapshots_desc",
                                   :locals  => {:selected => params[:id]})
      page.replace("snapshots_tree_div", :partial => "/vm_common/snapshots_tree")
    end
  end

  def disks
    #flag to show cursor as default in grid so rows don't look clickable
    @temp[:ro_grid] = true
    @grid_xml = build_disks_tree(@record)
  end

  def build_disks_tree(view)
    xml = REXML::Document.load("")
    xml << REXML::XMLDecl.new(1.0, "UTF-8")

    # Create root element
    root = xml.add_element("rows")
    # Build the header row
    hrow = root.add_element("head")
    grid_add_header(@record, hrow)

    # Sort disks by disk_name within device_type
    view.hardware.disks.sort{|x,y| cmp = x.device_type.to_s.downcase <=> y.device_type.to_s.downcase; cmp == 0 ? calculate_disk_name(x).downcase <=> calculate_disk_name(y).downcase : cmp }.each_with_index do |disk,idx|
      srow = root.add_element("row", {"id" => "Disk_#{idx}"})
      srow.add_element("cell", {"image" => "blank.gif", "title" => "Disk #{idx}"}).text = calculate_disk_name(disk)
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{disk.disk_type}"}).text = disk.disk_type
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{disk.mode}"}).text = disk.mode
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{disk.partitions_aligned}",}).text = disk.partitions_aligned
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{calculate_size(disk.size)}"}).text = calculate_size(disk.size)
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{calculate_size(disk.size_on_disk)}"}).text = calculate_size(disk.size_on_disk)
      srow.add_element("cell", {"image" => "blank.gif", "title" => "#{disk.used_percent_of_provisioned}"}).text = disk.used_percent_of_provisioned
    end
    return xml.to_s
  end

  def calculate_volume_name(vname)
    vname.blank? ? "Volume N/A" : "Volume #{vname}"
  end

  def calculate_size(size)
    size.blank? ? nil : number_to_human_size(size,:precision=>2)
  end

  def calculate_disk_name(disk)
    loc = disk.location.nil? ? "" : disk.location
    dev = "#{disk.controller_type} #{loc}"  # default device is controller_type
    # Customize disk entries by type
    if disk.device_type == "cdrom-raw"
      dev = "CD-ROM (IDE " << loc << ")"
    elsif disk.device_type == "atapi-cdrom"
      dev = "ATAPI CD-ROM (IDE " << loc << ")"
    elsif disk.device_type == "cdrom-image"
      dev = "CD-ROM Image (IDE " << loc << ")"
    elsif disk.device_type == "disk"
      if disk.controller_type == "ide"
        dev = "Hard Disk (IDE " << loc << ")"
      elsif disk.controller_type == "scsi"
        dev = "Hard Disk (SCSI " << loc << ")"
      end
    elsif disk.device_type == "ide"
      dev = "Hard Disk (IDE " << loc << ")"
    elsif ["scsi", "scsi-hardDisk"].include?(disk.device_type)
      dev = "Hard Disk (SCSI " << loc << ")"
    elsif disk.device_type == "scsi-passthru"
      dev = "Generic SCSI (" << loc << ")"
    elsif disk.device_type == "floppy"
      dev = dev
    end
    return dev
  end

  def grid_add_header(view, head)
    col_width = 100

    #disk
    new_column = head.add_element("column", {"width"=>"120","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Device Type"

    #device_type
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Type"

    #mode
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Mode"

    # alignment
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Partitions Aligned"

#     commented for FB6679
#   #filesystem
#   new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
#   new_column.add_attribute("type", 'ro')
#   new_column.text = "Filesystem"

    #size
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Provisioned Size"

    #size_on_disk
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Used Size"

    #used_percent_of_provisioned
    new_column = head.add_element("column", {"width"=>"#{col_width}","sort"=>"na"})
    new_column.add_attribute("type", 'ro')
    new_column.text = "Percent Used of Provisioned Size"
  end

  def show_association(action, display_name, listicon, method, klass, association = nil)
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    if @explorer  # Save vars for tree history array
      @action = action
      @x_show = params[:x_show]
    end
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    return if record_no_longer_exists?(@vm)
    rec_cls = "vm"

    @sb[:action] = @lastaction = action
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      if method.kind_of?(Array)
        obj = @record
        while meth = method.shift do
          obj = obj.send(meth)
        end
        @item = obj.find(from_cid(id))
      else
        @item = @record.send(method).find(from_cid(id))
      end

      drop_breadcrumb( { :name => "#{@record.name} (#{display_name})", :url=>"/#{rec_cls}/#{action}/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( { :name => @item.name,                      :url=>"/#{rec_cls}/#{action}/#{@record.id}?show=#{@item.id}"} )
      @view = get_db_view(klass, :association=>association)
      show_item
    else
      drop_breadcrumb( { :name => @record.name,                        :url=>"/#{rec_cls}/show/#{@record.id}"}, true )
      drop_breadcrumb( { :name => "#{@record.name} (#{display_name})", :url=>"/#{rec_cls}/#{action}/#{@record.id}"} )
      @listicon = listicon
      if association.nil?
        show_details(klass)
      else
        show_details(klass, :association => association )
      end
    end

  end

  def processes
    show_association('processes', 'Running Processes', 'processes', [:operating_system, :processes], OsProcess, 'processes')
  end

  def registry_items
    show_association('registry_items', 'Registry Entries', 'registry_items', :registry_items, RegistryItem)
  end

  def advanced_settings
    show_association('advanced_settings', 'Advanced Settings', 'advancedsetting', :advanced_settings, AdvancedSetting)
  end

  def linux_initprocesses
    show_association('linux_initprocesses', 'Init Processes', 'linuxinitprocesses', :linux_initprocesses, SystemService, 'linux_initprocesses')
  end

  def win32_services
    show_association('win32_services', 'Win32 Services', 'win32service', :win32_services, SystemService, 'win32_services')
  end

  def kernel_drivers
    show_association('kernel_drivers', 'Kernel Drivers', 'kerneldriver', :kernel_drivers, SystemService, 'kernel_drivers')
  end

  def filesystem_drivers
    show_association('filesystem_drivers', 'File System Drivers', 'filesystemdriver', :filesystem_drivers, SystemService, 'filesystem_drivers')
  end

  def filesystems
    show_association('filesystems', 'Files', 'filesystems', :filesystems, Filesystem)
  end

  def security_groups
    show_association('security_groups', 'Security Groups', 'security_group', :security_groups, SecurityGroup)
  end

  def snap
    assert_privileges(params[:pressed])
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    @name = @description = ""
    @in_a_form = true
    @button_group = "snap"
    drop_breadcrumb( {:name=>"Snapshot VM '" + @record.name + "'", :url=>"/vm_common/snap", :display=>"snapshot_info"} )
    if @explorer
      @edit ||= Hash.new
      @edit[:explorer] = true
      session[:changed] = true
      @refresh_partial = "vm_common/snap"
    end
  end
  alias vm_snapshot_add snap

  def snap_vm
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    if params["cancel"] || params[:button] == "cancel"
      flash = _("%s was cancelled by the user") % "Snapshot of VM #{@record.name}"
      if session[:edit] && session[:edit][:explorer]
        add_flash(flash)
        @_params[:display] = "snapshot_info"
        show
      else
        redirect_to :action=>@lastaction, :id=>@record.id, :flash_msg=>flash
      end
    elsif params["create.x"] || params[:button] == "create"
      @name = params[:name]
      @description = params[:description]
      if params[:name].blank?
        add_flash(_("%s is required") % "Name", :error)
        @in_a_form = true
        drop_breadcrumb( {:name=>"Snapshot VM '" + @record.name + "'", :url=>"/vm_common/snap"} )
        if session[:edit] && session[:edit][:explorer]
          @edit = session[:edit]    #saving it to use in next transaction
          render :partial => "shared/ajax/flash_msg_replace"
        else
          render :action=>"snap"
        end
      else
        flash_error = false
#       audit = {:event=>"vm_genealogy_change", :target_id=>@record.id, :target_class=>@record.class.base_class.name, :userid => session[:userid]}
        begin
          # @record.create_snapshot(params[:name], params[:description], params[:snap_memory])
          Vm.process_tasks( :ids          => [@record.id],
                            :task         => "create_snapshot",
                            :userid       => session[:userid],
                            :name         => params[:name],
                            :description  => params[:description],
                            :memory       => params[:snap_memory] == "1")
        rescue StandardError => bang
          puts bang.backtrace.join("\n")
          flash = _("Error during '%s': ") % "Create Snapshot" << bang.message; flash_error = true
#         AuditEvent.failure(audit.merge(:message=>"[#{@record.name} -- #{@record.location}] Update returned: #{bang}"))
        else
          flash = _("Create Snapshot for %{model} \"%{name}\" was started") % {:model=>ui_lookup(:model=>"Vm"), :name=>@record.name}
#         AuditEvent.success(build_saved_vm_audit(@record))
        end
        params[:id] = @record.id.to_s   # reset id in params for show
        #params[:display] = "snapshot_info"
        if session[:edit] && session[:edit][:explorer]
          add_flash(flash, flash_error ? :error : :info)
          @_params[:display] = "snapshot_info"
          show
        else
          redirect_to :action=>@lastaction, :id=>@record.id, :flash_msg=>flash, :flash_error=>flash_error, :display=>"snapshot_info"
        end
      end
    end
  end

  def policies
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    @lastaction = "rsop"
    @showtype = "policies"
    drop_breadcrumb( {:name=>"Policy Simulation Details for " + @record.name, :url=>"/vm/policies/#{@record.id}"} )
    @polArr = Array.new
    @record.resolve_profiles(session[:policies].keys).sort{|a,b| a["description"] <=> b["description"]}.each do | a |
      @polArr.push(a)
    end
    @policy_options = Hash.new
    @policy_options[:out_of_scope] = true
    @policy_options[:passed] = true
    @policy_options[:failed] = true
    build_policy_tree(@polArr)
    @edit = session[:edit] if session[:edit]
    if @edit && @edit[:explorer]
      @in_a_form = true
      replace_right_cell
    else
      render :template => 'vm/show'
    end
  end

  # policy simulation tree
  def build_policy_tree(profiles)
    session[:squash_open] = false
    vm_node = TreeNodeBuilder.generic_tree_node(
        "h_#{@record.name}",
        @record.name,
        "vm.png",
        @record.name,
        {:style_class => "cfme-no-cursor-node",
         :expand      => true
        }
    )
    vm_node[:title] = "<b>#{vm_node[:title]}</b>"
    vm_node[:children] = build_profile_nodes(profiles) if profiles.length > 0
    session[:policy_tree] = [vm_node].to_json
    session[:tree_name] = "rsop_tree"
  end

  def build_profile_nodes(profiles)
    profile_nodes = []
    profiles.each do |profile|
      if profile["result"] == "allow"
        icon = "checkmark.png"
      elsif profile["result"] == "N/A"
        icon = "na.png"
      else
        icon = "x.png"
      end
      profile_node = TreeNodeBuilder.generic_tree_node(
          "policy_profile_#{profile['id']}",
          profile['description'],
          icon,
          nil,
          {:style_class => "cfme-no-cursor-node"}
      )
      profile_node[:title] = "<b>Policy Profile:</b> #{profile_node[:title]}"
      profile_node[:children] = build_policy_node(profile["policies"]) if profile["policies"].length > 0

      if @policy_options[:out_of_scope] == false
        profile_nodes.push(profile_node) if profile["result"] != "N/A"
      else
        profile_nodes.push(profile_node)
      end
    end
    profile_nodes.push(build_empty_node) if profile_nodes.blank?
    profile_nodes
  end

  def build_empty_node
    TreeNodeBuilder.generic_tree_node(
        nil,
        "Items out of scope",
        "blank.gif",
        nil,
        {:style_class => "cfme-no-cursor-node"}
    )
  end

  def build_policy_node(policies)
    policy_nodes = []
    policies.sort_by{ |a| a["description"] }.each do |policy|
      active_caption = policy["active"] ? "" : " (Inactive)"
      if policy["result"] == "allow"
        icon = "checkmark.png"
      elsif policy["result"] == "N/A"
        icon = "na.png"
      else
        icon = "x.png"
      end
      policy_node = TreeNodeBuilder.generic_tree_node(
          "policy_#{policy["id"]}",
          policy['description'],
          icon,
          nil,
          {:style_class => "cfme-no-cursor-node"}
      )
      policy_node[:title] = "<b>Policy#{active_caption}:</b> #{policy_node[:title]}"
      policy_children = []
      policy_children.push(build_scope_or_expression_node(policy["scope"], "scope_#{policy["id"]}_#{policy["name"]}", "Scope")) if policy["scope"]
      policy_children.concat(build_condition_nodes(policy)) if policy["conditions"].length > 0
      policy_node[:children] = policy_children unless policy_children.empty?

      if @policy_options[:out_of_scope] == false && @policy_options[:passed] == true && @policy_options[:failed] == true
        policy_nodes.push(policy_node) if policy["result"] != "N/A"
      elsif @policy_options[:passed] == true && @policy_options[:failed] == false && @policy_options[:out_of_scope] == false
        policy_nodes.push(policy_node) if policy["result"] == "allow"
      elsif @policy_options[:passed] == true && @policy_options[:failed] == false && @policy_options[:out_of_scope] == true
        policy_nodes.push(policy_node) if policy["result"] == "N/A" || policy["result"] == "allow"
      elsif @policy_options[:failed] == true && @policy_options[:passed] == false
        policy_nodes.push(policy_node) if policy["result"] == "deny"
      elsif @policy_options[:out_of_scope] == true && @policy_options[:passed] == true && policy["result"] == "N/A"
        policy_nodes.push(policy_node)
      else
        policy_nodes.push(policy_node)
      end
    end
    policy_nodes
  end

  def build_condition_nodes(policy)
    condition_nodes = []
    policy["conditions"].sort_by{ |a| a["description"] }.each do |condition|
      if condition["result"] == "allow"
        icon = "checkmark.png"
      elsif condition["result"] == "N/A" || !condition["expression"]
        icon = "na.png"
      else
        icon = "x.png"
      end
      condition_node = TreeNodeBuilder.generic_tree_node(
          "condition_#{condition["id"]}_#{condition["name"]}_#{policy["name"]}",
          condition["description"],
          icon,
          nil,
          {:style_class => "cfme-no-cursor-node"}
      )
      condition_node[:title] = "<b>Condition:</b> #{condition_node[:title]}"
      condition_children = []
      condition_children.push(build_scope_or_expression_node(condition["scope"], "scope_#{condition["id"]}_#{condition["name"]}", "Scope")) if condition["scope"]
      condition_children.push(build_scope_or_expression_node(condition["expression"], "expression_#{condition["id"]}_#{condition["name"]}", "Expression")) if condition["expression"]
      condition_node[:children] = condition_children if !condition_children.blank?
      if @policy_options[:out_of_scope] == false
        condition_nodes.push(condition_node) if condition["result"] != "N/A"
      else
        condition_nodes.push(condition_node)
      end
    end
    condition_nodes
  end

  def build_scope_or_expression_node(scope_or_expression, node_key, title_prefix)
    exp_string,exp_tooltip = exp_build_string(scope_or_expression)
    if scope_or_expression["result"] == true
      icon = "checkmark.png"
    else
      icon = "na.png"
    end
    node = TreeNodeBuilder.generic_tree_node(
        node_key,
        exp_string.html_safe,
        icon,
        exp_tooltip.html_safe,
        {:style_class => "cfme-no-cursor-node"}
    )
    node[:title] = "<b>#{title_prefix}:</b> #{node[:title]}"

    if @policy_options[:out_of_scope] == false
      node if scope_or_expression["result"] != "N/A"
    else
      node
    end
  end

  def policy_show_options
    if params[:passed] == "null" || params[:passed] == ""
      @policy_options[:passed] = false
      @policy_options[:failed] = true
    elsif params[:failed] == "null" || params[:failed] == ""
      @policy_options[:passed] = true
      @policy_options[:failed] = false
    elsif params[:failed] == "1"
      @policy_options[:failed] = true
    elsif params[:passed] == "1"
      @policy_options[:passed] = true
    end
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    build_policy_tree(@polArr)
    render :update do |page|
      page.replace_html("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace_html("main_div", :partial => "vm_common/policies")
    end
  end

  # Show/Unshow out of scope items
  def policy_options
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    @policy_options ||= Hash.new
    @policy_options[:out_of_scope] = (params[:out_of_scope] == "1")
    build_policy_tree(@polArr)
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "#{session[:tree_name]}.saveOpenStates('#{session[:tree_name]}','path=/');"
      page << "#{session[:tree_name]}.loadOpenStates('#{session[:tree_name]}');"
      #page.replace("policy_options_div", :partial=>"vm/policy_options")
      page.replace("main_div", :partial=>"vm_common/policies")
    end
  end

  def toggle_policy_profile
    session[:policy_profile_compressed] = ! session[:policy_profile_compressed]
    @compressed = session[:policy_profile_compressed]
    render :update do |page|                                # Use RJS to update the display
      page.replace_html("view_buttons_div", :partial=>"layouts/view_buttons")   # Replace the view buttons
      page.replace_html("main_div", :partial=>"policies")   # Replace the main div area contents
    end
  end

  # Set right_size selected db records
  def right_size
    @record = Vm.find_by_id(params[:id])
    @lastaction = "right_size"
    @rightsize = true
    @in_a_form = true
    if params[:button] == "back"
      render :update do |page|
        page.redirect_to(previous_breadcrumb_url)
      end
    end
    if !@explorer && params[:button] != "back"
      drop_breadcrumb(:name => "Right Size VM '" + @record.name + "'", :url => "/vm/right_size")
      render :action=>"show"
    end
  end

  def evm_relationship
    @record = find_by_id_filtered(VmOrTemplate, params[:id])  # Set the VM object
    @edit = Hash.new
    @edit[:vm_id] = @record.id
    @edit[:key] = "evm_relationship_edit__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    evm_relationship_build_screen
    @edit[:current] = copy_hash(@edit[:new])
    session[:changed] = false
    @tabs = [ ["evm_relationship", @record.id.to_s], ["evm_relationship", "Edit Management Engine Relationship"] ]
    @in_a_form = true
    if @explorer
      @refresh_partial = "vm_common/evm_relationship"
      @edit[:explorer] = true
    end
  end
  alias image_evm_relationship evm_relationship
  alias instance_evm_relationship evm_relationship
  alias vm_evm_relationship evm_relationship
  alias miq_template_evm_relationship evm_relationship

  # Build the evm_relationship assignment screen
  def evm_relationship_build_screen
    @servers = Hash.new   # Users array for first chooser
    MiqServer.all.each{|s| @servers["#{s.name} (#{s.id})"] = s.id.to_s}
    @edit[:new][:server] = @record.miq_server ? @record.miq_server.id.to_s : nil            # Set to first category, if not already set
  end

  def evm_relationship_field_changed
    return unless load_edit("evm_relationship_edit__new")
    evm_relationship_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def evm_relationship_get_form_vars
    @record = VmOrTemplate.find_by_id(@edit[:vm_id])
    @edit[:new][:server] = params[:server_id] if params[:server_id]
  end

  def evm_relationship_update
    return unless load_edit("evm_relationship_edit__new")
    evm_relationship_get_form_vars
    case params[:button]
    when "cancel"
      msg = _("%s was cancelled by the user") % "Edit Management Engine Relationship"
      if @edit[:explorer]
        add_flash(msg)
        @sb[:action] = nil
        replace_right_cell
      else
        render :update do |page|
          page.redirect_to :action=>'show', :id=>@record.id, :flash_msg=>msg
        end
      end
    when "save"
      svr = @edit[:new][:server] && @edit[:new][:server] != "" ? MiqServer.find(@edit[:new][:server]) : nil
      @record.miq_server = svr
      @record.save
      msg = _("%s saved") % "Management Engine Relationship"
      if @edit[:explorer]
        add_flash(msg)
        @sb[:action] = nil
        replace_right_cell
      else
        render :update do |page|
          page.redirect_to :action=>'show', :id=>@record.id,:flash_msg=>msg
        end
      end
    when "reset"
      @in_a_form = true
      if @edit[:explorer]
        @explorer = true
        evm_relationship
        add_flash(_("All changes have been reset"), :warning)
        replace_right_cell
      else
        render :update do |page|
          page.redirect_to :action=>'evm_relationship', :id=>@record.id, :flash_msg=>_("All changes have been reset"), :flash_warning=>true, :escape=>true
        end
      end
    end
  end

  def delete
    @lastaction = "delete"
    redirect_to :action => 'show_list', :layout=>false
  end

  def destroy
    find_by_id_filtered(VmOrTemplate, params[:id]).destroy
    redirect_to :action => 'list'
  end

  def profile_build
   session[:vm].resolve_profiles(session[:policies].keys).sort{|a,b| a["description"] <=> b["description"]}.each do | policy |
      @catinfo ||= Hash.new                               # Hash to hold category squashed states
      policy.each do | key, cat|
       if key == "description"
        if @catinfo[cat] ==  nil
          @catinfo[cat] = true                                # Set compressed if no entry present yet
        end
       end
      end
    end
  end

  def profile_toggle
    if params[:pressed] == "tag_cat_toggle"
      profile_build
      policy_escaped = j(params[:policy])
      cat            = params[:cat]
      render :update do |page|
        if @catinfo[cat]
          @catinfo[cat] = false
          page << javascript_show("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', '/images/tree/compress.png');"
        else
          @catinfo[cat] = true # Set squashed = true
          page << javascript_hide("cat_#{policy_escaped}_div")
          page << "$('#cat_#{policy_escaped}_icon').prop('src', '/images/tree/expand.png');"
        end
      end
    else
      add_flash(_("Button not yet implemented"), :error)
      render :partial => "shared/ajax/flash_msg_replace"
    end
  end

  def add_to_service
    @record = find_by_id_filtered(Vm, params[:id])
    @svcs = Hash.new
    Service.all.each {|s| @svcs[s.name] = s.id }
    drop_breadcrumb( {:name=>"Add VM to a Service", :url=>"/vm/add_to_service"} )
    @in_a_form = true
  end

  def add_vm_to_service
    @record = find_by_id_filtered(Vm, params[:id])
    if params["cancel.x"]
      flash = _("Add VM \"%s\" to a Service was cancelled by the user") % @record.name
      redirect_to :action=>@lastaction, :id=>@record.id, :flash_msg=>flash
    else
      chosen = params[:chosen_service].to_i
      flash = _("%{model} \"%{name}\" successfully added to Service \"%{to_name}\"") % {:model=>ui_lookup(:model=>"Vm"), :name=>@record.name, :to_name=>Service.find(chosen).name}
      begin
        @record.add_to_vsc(Service.find(chosen).name)
      rescue StandardError => bang
        flash = _("Error during '%s': ") % "Add VM to service" << bang
      end
      redirect_to :action => @lastaction, :id=>@record.id, :flash_msg=>flash
    end
  end

  def remove_service
    assert_privileges(params[:pressed])
    @record = find_by_id_filtered(Vm, params[:id])
    begin
      @vervice_name = Service.find_by_name(@record.location).name
      @record.remove_from_vsc(@vervice_name)
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "Remove VM from service" + bang.message, :error)
    else
      add_flash(_("VM successfully removed from service \"%s\"") % @vervice_name)
    end
  end

  def edit
    @record = find_by_id_filtered(VmOrTemplate, params[:id])  # Set the VM object
    set_form_vars
    build_edit_screen
    session[:changed] = false
    @tabs = [ ["edit", @record.id.to_s], ["edit", "Information"] ]
    @refresh_partial = "vm_common/form"
  end
  alias image_edit edit
  alias instance_edit edit
  alias vm_edit edit
  alias miq_template_edit edit

  def build_edit_screen
    drop_breadcrumb(:name => "Edit VM '" + @record.name + "'", :url => "/vm/edit") unless @explorer
    session[:edit] = @edit
    @in_a_form = true
    @tabs = [ ["edit", @record.id.to_s], ["edit", "Information"] ]
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("vm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace_html("main_div",
                        :partial => "vm_common/form") if %w(allright left right).include?(params[:button])
      page << javascript_for_miq_button_visibility(changed) if changed
      page << "miqSparkle(false);"
    end
  end

  def edit_vm
    return unless load_edit("vm_edit__#{params[:id]}")
    #reset @explorer if coming from explorer views
    @explorer = true if @edit[:explorer]
    get_form_vars
    case params[:button]
    when "cancel"
      if @edit[:explorer]
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>@record.class.base_model.name), :name=>@record.name})
        @record = @sb[:action] = nil
        replace_right_cell
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "Vm"), :name => @record.name})
        session[:flash_msgs] = @flash_array.dup
        render :update do |page|
          page.redirect_to(previous_breadcrumb_url)
        end
      end
    when "save"
      if @edit[:new][:parent] != -1 && @edit[:new][:kids].invert.include?(@edit[:new][:parent]) # Check if parent is a kid, if selected
        add_flash(_("Parent VM can not be one of the child VMs"), :error)
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        build_edit_screen
        if @edit[:explorer]
          replace_right_cell
        else
          render :action=>"edit"
        end
      else
        current = @record.parents.length == 0 ? -1 : @record.parents.first.id                             # get current parent id
        chosen = @edit[:new][:parent].to_i                                                          # get the chosen parent id
        @record.custom_1 = @edit[:new][:custom_1]
        @record.description = @edit[:new][:description]                                                 # add vm description
        if current != chosen
          @record.remove_parent(@record.parents.first) unless current == -1                           # Remove existing parent, if there is one
          @record.set_parent(VmOrTemplate.find(chosen)) unless chosen == -1                                   # Set new parent, if one was chosen
        end
        vms = @record.children                                                                                      # Get the VM's child VMs
        kids = @edit[:new][:kids].invert                                                                        # Get the VM ids from the kids list box
        audit = {:event=>"vm_genealogy_change", :target_id=>@record.id, :target_class=>@record.class.base_class.name, :userid => session[:userid]}
        begin
          @record.save!
          vms.each { |v| @record.remove_child(v) if !kids.include?(v.id) }                                # Remove any VMs no longer in the kids list box
          kids.each_key { |k| @record.set_child(VmOrTemplate.find(k)) }                                             # Add all VMs in kids hash, dups will not be re-added
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") % "#{@record.class.base_model.name} update" << bang.message, :error)
          AuditEvent.failure(audit.merge(:message=>"[#{@record.name} -- #{@record.location}] Update returned: #{bang}"))
        else
          flash = _("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>@record.class.base_model.name), :name=>@record.name}
          AuditEvent.success(build_saved_vm_audit(@record))
        end
        params[:id] = @record.id.to_s   # reset id in params for show
        @record = nil
        add_flash(flash)
        if @edit[:explorer]
          @sb[:action] = nil
          replace_right_cell
        else
          session[:flash_msgs] = @flash_array.dup
          render :update do |page|
            page.redirect_to(previous_breadcrumb_url)
          end
        end
      end
    when "reset"
      edit
      add_flash(_("All changes have been reset"), :warning)
      session[:flash_msgs] = @flash_array.dup
      get_vm_child_selection if params["right.x"] || params["left.x"] || params["allright.x"]
      @changed = session[:changed] = false
      build_edit_screen
      if @edit[:explorer]
        replace_right_cell
      else
        render :update do |page|
          page.redirect_to(:action => "edit", :controller => "vm", :id => params[:id])
        end
      end
    else
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      build_edit_screen
      if @edit[:explorer]
        replace_right_cell
      else
        render :action=>"edit"
      end
    end
  end

  def set_checked_items
    session[:checked_items] = Array.new
    if params[:all_checked]
      ids = params[:all_checked].split(',')
      ids.each do |id|
        id = id.split('-')
        id = id[1].slice(0,id[1].length-1)
        session[:checked_items].push(id) unless session[:checked_items].include?(id)
      end
    end
    @lastaction = "set_checked_items"
    render :nothing => true
  end

  def scan_history
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    @scan_history  = ScanHistory.find_by_vm_or_template_id(@record.id)
    @listicon = "scan_history"
    @showtype = "scan_history"
    @lastaction = "scan_history"
    @gtl_url = "/vm/scan_history/?"
    @no_checkboxes = true
    @showlinks = true

    @view, @pages = get_view(ScanHistory, :parent=>@record) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] if @pages != nil # save the current page number
    if @scan_history.nil?
      drop_breadcrumb( {:name=>@record.name + " (Analysis History)", :url=>"/vm/#{@record.id}"} )
    else
      drop_breadcrumb( {:name=>@record.name + " (Analysis History)", :url=>"/vm/scan_history/#{@scan_history.vm_or_template_id}"} )
    end

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      render :update do |page|
        page.replace_html("gtl_div", :partial=>"layouts/gtl")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    else
      if @explorer || request.xml_http_request? # Is this an Ajax request?
        @sb[:action] = params[:action]
        @refresh_partial = "layouts/#{@showtype}"
        replace_right_cell
      else
        render :action => 'show'
      end
    end
  end

  def scan_histories
    @vm = @record = identify_record(params[:id], VmOrTemplate)
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @scan_history  = ScanHistory.find_by_vm_or_template_id(@record.id)
    if @scan_history == nil
      redirect_to :action=>"scan_history", :flash_msg=>_("Error: Record no longer exists in the database"), :flash_error=>true
      return
    end
    @lastaction = "scan_histories"
    @sb[:action] = params[:action]
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = ScanHistory.find(from_cid(id))
      drop_breadcrumb( {:name=>time_ago_in_words(@item.started_on.in_time_zone(Time.zone)).titleize, :url=>"/vm/scan_history/#{@scan_history.vm_or_template_id}?show=#{@item.id}"} )
      @view = get_db_view(ScanHistory)          # Instantiate the MIQ Report view object
      show_item
    else
      drop_breadcrumb( {:name=>time_ago_in_words(@scan_history.started_on.in_time_zone(Time.zone)).titleize, :url=>"/vm/show/#{@scan_history.vm_or_template_id}"}, true )
      @listicon = "scan_history"
      show_details(ScanHistory)
    end
  end

  # Tree node selected in explorer
  def tree_select
    @explorer = true
    @lastaction = "explorer"
    @sb[:action] = nil

    # Need to see if record is unauthorized if it's a VM node
    @nodetype, id = params[:id].split("_").last.split("-")
    @vm = @record = identify_record(id, VmOrTemplate) if ["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(@nodetype)) && !@record

    # Handle filtered tree nodes
    if x_tree[:type] == :filter &&
        !["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(@nodetype))
      search_id = @nodetype == "root" ? 0 : from_cid(id)
      adv_search_build(vm_model_from_active_tree(x_active_tree))
      session[:edit] = @edit              # Set because next method will restore @edit from session
      listnav_search_selected(search_id) unless params.has_key?(:search_text) # Clear or set the adv search filter
      if @edit[:adv_search_applied] &&
          MiqExpression.quick_search?(@edit[:adv_search_applied][:exp]) &&
          %w(reload tree_select).include?(params[:action])
        self.x_node = params[:id]
        quick_search_show
        return
      end
    end

    unless @unauthorized
      self.x_node = params[:id]
      replace_right_cell
    else
      add_flash("User is not authorized to view #{ui_lookup(:model=>@record.class.base_model.to_s)} \"#{@record.name}\"", :error)
      render :partial => "shared/tree_select_error", :locals => {:options => {:select_node => x_node}}
    end
  end

  # Accordion selected in explorer
  def accordion_select
    @lastaction = "explorer"
    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"
    @sb[:action] = nil
    replace_right_cell
  end

  private

  # First time thru, kick off the acquire ticket task
  def console_before_task(console_type)
    ticket_type = console_type.to_sym

    record = identify_record(params[:id], VmOrTemplate)
    ems = record.ext_management_system
    if ems.class.ems_type == 'vmwarews'
      ticket_type = :vnc if console_type == 'html5'
      begin
        ems.validate_remote_console_vmrc_support
      rescue MiqException::RemoteConsoleNotSupportedError => e
        add_flash(_("Console access failed: %s") % e.message, :error)
        render :partial => "shared/ajax/flash_msg_replace"
        return
      end
    end

    task_id = record.remote_console_acquire_ticket_queue(ticket_type, session[:userid], MiqServer.my_server.id)
    add_flash(_("Console access failed: %s") % "Task start failed: ID [#{task_id.inspect}]", :error) unless task_id.is_a?(Fixnum)

    if @flash_array
      render :partial => "shared/ajax/flash_msg_replace"
    else
      initiate_wait_for_task(:task_id => task_id)
    end
  end

  # Task complete, show error or launch console using VNC/MKS/VMRC task info
  def console_after_task(console_type)
    miq_task = MiqTask.find(params[:task_id])
    if miq_task.status == "Error" || miq_task.task_results.blank?
      add_flash(_("Console access failed: %s") % miq_task.message, :error)
    else
      @vm = @record = identify_record(params[:id], VmOrTemplate)
      @sb[console_type.to_sym] = miq_task.task_results # html5, VNC?, MKS or VMRC
    end
    render :update do |page|
      if @flash_array
        page.replace(:flash_msg_div, :partial => "layouts/flash_msg")
        page << "miqSparkle(false);"
      else # open a window to show a VNC or VMWare console
        console_action = console_type == 'html5' ? 'launch_html5_console' : 'launch_vmware_console'
        page << "miqSparkle(false);"
        page << "window.open('#{url_for :controller => controller_name, :action => console_action, :id => @record.id}');"
      end
    end
  end

  # Check for parent nodes missing from vandt tree and return them if any
  def open_parent_nodes(record)
    add_nodes = nil
    existing_node = nil                     # Init var

    if record.orphaned? || record.archived?
      parents = [{:type=>"x", :id=>"#{record.orphaned ? "orph" : "arch"}"}]
    else
      if x_active_tree == :instances_tree
        parents = record.kind_of?(VmCloud) && record.availability_zone ? [record.availability_zone] : [record.ext_management_system]
      else
        parents = record.parent_blue_folders({:exclude_non_display_folders=>true})
      end
    end

    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    unless parents.empty? ||  # Skip if no parents or parent already open
        x_tree[:open_nodes].include?(x_build_node_id(parents.last))
      parents.reverse.each do |p|
        p_node = x_build_node_id(p)
        unless x_tree[:open_nodes].include?(p_node)
          x_tree[:open_nodes].push(p_node)
          existing_node = p_node
        end
      end
    end

    # Start at the EMS if record has an EMS and it's not opened yet
    if record.ext_management_system
      ems_node = x_build_node_id(record.ext_management_system)
      unless x_tree[:open_nodes].include?(ems_node)
        x_tree[:open_nodes].push(ems_node)
        existing_node = ems_node
      end
    end

    add_nodes = {:key => existing_node, :children => tree_add_child_nodes(existing_node)} if existing_node
    return add_nodes
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    #resetting action that was stored during edit to determine what is being edited
    @sb[:action] = nil
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    model, title =  case x_active_tree.to_s
                      when "images_filter_tree"
                        ["TemplateCloud", "Images"]
                      when "images_tree"
                        ["TemplateCloud", "Images by Provider"]
                      when "instances_filter_tree"
                        ["VmCloud", "Instances"]
                      when "instances_tree"
                        ["VmCloud", "Instances by Provider"]
                      when "vandt_tree"
                        ["VmOrTemplate", "VMs & Templates"]
                      when "vms_instances_filter_tree"
                        ["Vm", "VMs & Instances"]
                      when "templates_images_filter_tree"
                        ["MiqTemplate", "Templates & Images"]
                      when "templates_filter_tree"
                        ["TemplateInfra", "Templates"]
                      when "vms_filter_tree"
                        ["VmInfra", "VMs"]
                      else
                        [nil, nil]
                    end
    case TreeBuilder.get_model_for_prefix(@nodetype)
    when "Vm", "MiqTemplate"  # VM or Template record, show the record
      show_record(from_cid(id))
      if @record.nil?
        self.x_node = "root"
        get_node_info("root")
        return
      else
        @right_cell_text = _("%{model} \"%{name}\"") % {:name=>@record.name, :model=>"#{ui_lookup(:model => model && model != "VmOrTemplate" ? model : TreeBuilder.get_model_for_prefix(@nodetype))}"}
      end
    else      # Get list of child VMs of this node
      options = {:model=>model}
      if x_node == "root"
        # TODO: potential to move this into a model with a scope built into it
        options[:where_clause] =
          ["vms.type IN (?)", VmInfra::SUBCLASSES + TemplateInfra::SUBCLASSES] if x_active_tree == :vandt_tree
        process_show_list(options)  # Get all VMs & Templates
        # :model=>ui_lookup(:models=>"VmOrTemplate"))
        # TODO: Change ui_lookup/dictionary to handle VmOrTemplate, returning VMs And Templates
        @right_cell_text = _("All %s") % title ? "#{title}" : "VMs & Templates"
      else
        if TreeBuilder.get_model_for_prefix(@nodetype) == "Hash"
          options[:where_clause] =
            ["vms.type IN (?)", VmInfra::SUBCLASSES + TemplateInfra::SUBCLASSES] if x_active_tree == :vandt_tree
          if id == "orph"
            options[:where_clause] = MiqExpression.merge_where_clauses(options[:where_clause], VmOrTemplate::ORPHANED_CONDITIONS)
            process_show_list(options)
            @right_cell_text = "Orphaned #{model ? ui_lookup(:models => model) : "VMs & Templates"}"
          elsif id == "arch"
            options[:where_clause] = MiqExpression.merge_where_clauses(options[:where_clause], VmOrTemplate::ARCHIVED_CONDITIONS)
            process_show_list(options)
            @right_cell_text = "Archived #{model ? ui_lookup(:models => model) : "VMs & Templates"}"
          end
        elsif TreeBuilder.get_model_for_prefix(@nodetype) == "MiqSearch"
          process_show_list(options)  # Get all VMs & Templates
          @right_cell_text = _("All %s") % model ? "#{ui_lookup(:models=>model)}" : "VMs & Templates"
        else
          rec = TreeBuilder.get_model_for_prefix(@nodetype).constantize.find(from_cid(id))
          options.merge!({:association=>"#{@nodetype == "az" ? "vms" : "all_vms_and_templates"}", :parent=>rec})
          process_show_list(options)
          model_name = @nodetype == "d" ? "Datacenter" : ui_lookup(:model=>rec.class.base_class.to_s)
          @is_redhat = case model_name
          when 'Datacenter' then EmsInfra.find(rec.ems_id).type == 'EmsRedhat'
          when 'Provider'   then rec.type == 'EmsRedhat'
          else false
          end
#       @right_cell_text = "#{ui_lookup(:models=>"VmOrTemplate")} under #{model_name} \"#{rec.name}\""
# TODO: Change ui_lookup/dictionary to handle VmOrTemplate, returning VMs And Templates
          @right_cell_text = "#{model ? ui_lookup(:models => model) : "VMs & Templates"} under #{model_name} \"#{rec.name}\""
        end
      end
      # Add adv search filter to header
      @right_cell_text += @edit[:adv_search_applied][:text] if @edit && @edit[:adv_search_applied]
    end

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id=>x_node,
                         :qs_exp=>@edit[:adv_search_applied][:qs_exp],
                         :text=>@right_cell_text)
    else
      x_history_add_item(:id=>treenodeid, :text=>@right_cell_text)  # Add to history pulldown array
    end

    # After adding to history, add name filter suffix if showing a list
    unless ["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(@nodetype))
      unless @search_text.blank?
        @right_cell_text += _(" (Names with \"%s\")") % @search_text
      end
    end

  end

  # Replace the right cell of the explorer
  def replace_right_cell(action=nil)
    @explorer = true
    @sb[:action] = action if !action.nil?
    if @sb[:action] || params[:display]
      partial, action, @right_cell_text = set_right_cell_vars # Set partial name, action and cell header
    end

    if !@in_a_form && !@sb[:action]
      get_node_info(x_node)
      #set @delete_node since we don't rebuild vm tree
      @delete_node = params[:id] if @replace_trees  #get_node_info might set this
      type, id = x_node.split("_").last.split("-")

      record_showing = type && ["Vm", "MiqTemplate"].include?(TreeBuilder.get_model_for_prefix(type))
      c_buttons,  c_xml  = build_toolbar_buttons_and_xml(center_toolbar_filename) # Use vm or template tb
      if record_showing
        cb_buttons, cb_xml = build_toolbar_buttons_and_xml("custom_buttons_tb")
        v_buttons,  v_xml  = build_toolbar_buttons_and_xml("x_summary_view_tb")
      else
        v_buttons,  v_xml  = build_toolbar_buttons_and_xml("x_gtl_view_tb")
      end
    elsif ["compare","drift"].include?(@sb[:action])
      @in_a_form = true # Turn on Cancel button
      c_buttons, c_xml = build_toolbar_buttons_and_xml("#{@sb[:action]}_center_tb")
      v_buttons, v_xml = build_toolbar_buttons_and_xml("#{@sb[:action]}_view_tb")
    elsif @sb[:action] == "performance"
      c_buttons, c_xml = build_toolbar_buttons_and_xml("x_vm_performance_tb")
    elsif @sb[:action] == "drift_history"
      c_buttons, c_xml = build_toolbar_buttons_and_xml("drifts_center_tb")  # Use vm or template tb
    elsif ["snapshot_info","vmtree_info"].include?(@sb[:action])
      c_buttons, c_xml = build_toolbar_buttons_and_xml("x_vm_center_tb")  # Use vm or template tb
    end
    h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb") unless @in_a_form

    unless x_active_tree == :vandt_tree
      # Clicked on right cell record, open the tree enough to show the node, if not already showing
      if params[:action] == "x_show" && @record &&          # Showing a record
          !@in_a_form &&                                     # Not in a form
          x_tree[:type] != :filter                           # Not in a filter tree
        add_nodes = open_parent_nodes(@record)              # Open the parent nodes of selected record, if not open
      end
    end

    # Build presenter to render the JS command for the tree update
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :temp        => @temp,
      :add_nodes   => add_nodes,         # Update the tree with any new nodes
      :delete_node => @delete_node,      # Remove a new node from the tree
    )
    r = proc { |opts| render_to_string(opts) }

    add_ajax = false
    if record_showing
      presenter[:set_visible_elements][:form_buttons_div] = false
      path_dir = @record.kind_of?(VmCloud) || @record.kind_of?(TemplateCloud) ? "vm_cloud" : "vm_common"
      presenter[:update_partials][:main_div] = r[:partial=>"#{path_dir}/main", :locals=>{:controller=>'vm'}]
    elsif @in_a_form
      partial_locals = {:controller=>'vm'}
      partial_locals[:action_url] = @lastaction if partial == 'layouts/x_gtl'
      presenter[:update_partials][:main_div] = r[:partial=>partial, :locals=>partial_locals]

      locals = {:action_url => action, :record_id => @record ? @record.id : nil}
      if ['clone', 'migrate', 'miq_request_new', 'pre_prov', 'publish', 'reconfigure', 'retire'].include?(@sb[:action])
        locals[:no_reset]        = true                                                                               # don't need reset button on the screen
        locals[:submit_button]   = ['clone', 'migrate', 'publish', 'reconfigure', 'pre_prov'].include?(@sb[:action])  # need submit button on the screen
        locals[:continue_button] = ['miq_request_new'].include?(@sb[:action])                                         # need continue button on the screen
        update_buttons(locals) if @edit && @edit[:buttons].present?
        presenter[:clear_tree_cookies] = "prov_trees"
      end

      if ['snapshot_add'].include?(@sb[:action])
        locals[:no_reset]      = true
        locals[:create_button] = true
      end

      if @record.kind_of?(Dialog)
        @record.dialog_fields.each do |field|
          if %w(DialogFieldDateControl DialogFieldDateTimeControl).include?(field.type)
            presenter[:build_calendar]  = {
              :date_from => field.show_past_dates ? nil : Time.now.in_time_zone(session[:user_tz]).to_i * 1000
            }
          end
        end
      end

      if %w(ownership protect reconfigure retire tag).include?(@sb[:action])
        locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
        locals[:record_id]    = @sb[:rec_id] || @edit[:object_ids][0] if @sb[:action] == "tag"
        unless @sb[:action] == 'ownership'
          presenter[:build_calendar] = {
            :date_from => Time.now.in_time_zone(@tz).to_i * 1000,
            :date_to   => nil,
          }
        end
      end

      add_ajax = true

      if ['compare', 'drift'].include?(@sb[:action])
        presenter[:update_partials][:custom_left_cell_div] = r[
          :partial => 'layouts/listnav/x_compare_sections', :locals => {:truncate_length => 23}]
        presenter[:cell_a_view] = 'custom'
      end
    elsif @sb[:action] || params[:display]
      partial_locals = {
        :controller => ['ontap_storage_volumes', 'ontap_file_shares', 'ontap_logical_disks',
          'ontap_storage_systems'].include?(@showtype) ? @showtype.singularize : 'vm'
      }
      if partial == 'layouts/x_gtl'
        partial_locals[:action_url]  = @lastaction
        presenter[:miq_parent_id]    = @record.id           # Set parent rec id for JS function miqGridSort to build URL
        presenter[:miq_parent_class] = request[:controller] # Set parent class for URL also
      end
      presenter[:update_partials][:main_div] = r[:partial=>partial, :locals=>partial_locals]

      add_ajax = true
      presenter[:build_calendar] = true
    else
      presenter[:update_partials][:main_div] = r[:partial=>'layouts/x_gtl']
    end

    presenter[:ajax_action] = {
      :controller => request.parameters["controller"],
      :action     => @ajax_action,
      :record_id  => @record.id
    } if add_ajax && ['performance','timeline'].include?(@sb[:action])

    # Replace the searchbox
    presenter[:replace_partials][:adv_searchbox_div] = r[
      :partial => 'layouts/x_adv_searchbox',
      :locals  => {:nameonly => ([:images_tree, :instances_tree, :vandt_tree].include?(x_active_tree))}
    ]

    # Clear the JS gtl_list_grid var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'
    presenter[:clear_tree_cookies] = "edit_treeOpenStatex" if @sb[:action] == "policy_sim"

    # Handle bottom cell
    if @pages || @in_a_form
      if @pages && !@in_a_form
        @ajax_paging_buttons = true # FIXME: this should not be done this way
        if @sb[:action] && @record  # Came in from an action link
          presenter[:update_partials][:paging_div] = r[
            :partial => 'layouts/x_pagingcontrols',
            :locals => {
              :action_url    => @sb[:action],
              :action_method => @sb[:action], # FIXME: action method and url the same?!
              :action_id     => @record.id
            }
          ]
        else
          presenter[:update_partials][:paging_div] = r[:partial => 'layouts/x_pagingcontrols']
        end
        presenter[:set_visible_elements][:form_buttons_div] = false
        presenter[:set_visible_elements][:pc_div_1] = true
      elsif @in_a_form
        if @sb[:action] == 'dialog_provision'
          presenter[:update_partials][:form_buttons_div] = r[
            :partial => 'layouts/x_dialog_buttons',
            :locals  => {
              :action_url => action,
              :record_id  => @edit[:rec_id],
            }
          ]
        else
          presenter[:update_partials][:form_buttons_div] = r[:partial => 'layouts/x_edit_buttons', :locals => locals]
        end
        presenter[:set_visible_elements][:pc_div_1] = false
        presenter[:set_visible_elements][:form_buttons_div] = true
      end
      presenter[:expand_collapse_cells][:c] = 'expand'
    else
      presenter[:expand_collapse_cells][:c] = 'collapse'
    end

    presenter[:right_cell_text] = @right_cell_text
    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons  && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons  && c_xml
    presenter[:set_visible_elements][:view_buttons_div]    = v_buttons  && v_xml
    presenter[:set_visible_elements][:custom_buttons_div]  = cb_buttons && cb_xml

    presenter[:reload_toolbars][:history] = {:buttons => h_buttons,  :xml => h_xml}  if h_buttons  && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons,  :xml => c_xml}  if c_buttons  && c_xml
    presenter[:reload_toolbars][:view]    = {:buttons => v_buttons,  :xml => v_xml}  if v_buttons  && v_xml
    presenter[:reload_toolbars][:custom]  = {:buttons => cb_buttons, :xml => cb_xml} if cb_buttons && cb_xml

    presenter[:expand_collapse_cells][:a] = h_buttons || c_buttons || v_buttons ? 'expand' : 'collapse'

    presenter[:miq_record_id] = @record ? @record.id : nil

    # Hide/show searchbox depending on if a list is showing
    presenter[:set_visible_elements][:adv_searchbox_div] = !(@record || @in_a_form)

    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    # Save open nodes, if any were added
    presenter[:save_open_states_trees] = [x_active_tree.to_s] if add_nodes

    presenter[:set_visible_elements][:blocker_div]    = false unless @edit && @edit[:adv_search_open]
    presenter[:set_visible_elements][:quicksearchbox] = false
    presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit
    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  # get the host that this vm belongs to
  def get_host_for_vm(vm)
    if vm.host
      @hosts = Array.new
      @hosts.push vm.host
    end
  end

  # Set form variables for edit
  def set_form_vars
    @edit = Hash.new
    @edit[:vm_id] = @record.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "vm_edit__#{@record.id || "new"}"
    @edit[:explorer] = true if params[:action] == "x_button" || session.fetch_path(:edit, :explorer)

    @edit[:current][:custom_1] = @edit[:new][:custom_1] = @record.custom_1.to_s
    @edit[:current][:description] = @edit[:new][:description] = @record.description.to_s
    @edit[:pchoices] = Hash.new                                 # Build a hash for the parent choices box
    VmOrTemplate.all.each { |vm| @edit[:pchoices][vm.name + " -- #{vm.location}"] =  vm.id unless vm.id == @record.id }   # Build a hash for the parents to choose from, not matching current VM
    @edit[:pchoices]['"no parent"'] = -1                        # Add "no parent" entry
    if @record.parents.length == 0                                            # Set the currently selected parent
      @edit[:new][:parent] = -1
    else
      @edit[:new][:parent] = @record.parents.first.id
    end

    vms = @record.children                                                      # Get the child VMs
    @edit[:new][:kids] = Hash.new
    vms.each { |vm| @edit[:new][:kids][vm.name + " -- #{vm.location}"] = vm.id }      # Build a hash for the kids list box

    @edit[:choices] = Hash.new
    VmOrTemplate.all.each { |vm| @edit[:choices][vm.name + " -- #{vm.location}"] =  vm.id if vm.parents.length == 0 }   # Build a hash for the VMs to choose from, only if they have no parent
    @edit[:new][:kids].each_key { |key| @edit[:choices].delete(key) }   # Remove any VMs that are in the kids list box from the choices

    @edit[:choices].delete(@record.name + " -- #{@record.location}")                                    # Remove the current VM from the choices list

    @edit[:current][:parent] = @edit[:new][:parent]
    @edit[:current][:kids] = @edit[:new][:kids].dup
    session[:edit] = @edit
  end

  #set partial name and cell header for edit screens
  def set_right_cell_vars
    name = @record ? @record.name.to_s.gsub(/'/,"\\\\'") : "" # If record, get escaped name
    table = request.parameters["controller"]
    case @sb[:action]
    when "compare","drift"
      partial = "layouts/#{@sb[:action]}"
      if @sb[:action] == "compare"
        header = _("Compare %s") %  ui_lookup(:model => @sb[:compare_db])
      else
        header = _("Drift for %{model} \"%{name}\"") % {:name => name, :model => ui_lookup(:model => @sb[:compare_db])}
      end
      action = nil
    when "clone","migrate","publish"
      partial = "miq_request/prov_edit"
      header = _("%{task} %{model}") % {:task=>@sb[:action].capitalize, :model=>ui_lookup(:table => table)}
      action = "prov_edit"
    when "dialog_provision"
      partial = "shared/dialogs/dialog_provision"
      header = @right_cell_text
      action = "dialog_form_button_pressed"
    when "edit"
      partial = "vm_common/form"
      header = _("Editing %{model} \"%{name}\"") % {:name=>name, :model=>ui_lookup(:table => table)}
      action = "edit_vm"
    when "evm_relationship"
      partial = "vm_common/evm_relationship"
      header = _("Edit CFME Server Relationship for %{model} \"%{name}\"") % {:model=>ui_lookup(:table => table), :name => name}
      action = "evm_relationship_update"
    #when "miq_request_new"
    # partial = "miq_request/prov_edit"
    # header = _("Provision %s") % ui_lookup(:models=>"Vm")
    # action = "prov_edit"
    when "miq_request_new"
      partial = "miq_request/pre_prov"
      typ = request.parameters[:controller] == "vm_cloud" ? "an #{ui_lookup(:table => "template_cloud")}" : "a #{ui_lookup(:table => "template_infra")}"
      header = _("Provision %{model} - Select %{typ}") % {:model=>ui_lookup(:tables => table), :typ => typ}
      action = "pre_prov"
    when "pre_prov"
      partial = "miq_request/prov_edit"
      header = _("Provision %s") % ui_lookup(:tables => table)
      action = "pre_prov_continue"
    when "pre_prov_continue"
      partial = "miq_request/prov_edit"
      header = _("Provision %s") %  ui_lookup(:tables => table)
      action = "prov_edit"
    when "ownership"
      partial = "shared/views/ownership"
      header = _("Set Ownership for %s") % ui_lookup(:table => table)
      action = "ownership_update"
    when "performance"
      partial = "layouts/performance"
      header = _("Capacity & Utilization data for %{model} \"%{name}\"") % {:model=>ui_lookup(:table => table), :name => name}
      x_history_add_item(:id=>x_node, :text=>header, :button=>params[:pressed], :display=>params[:display])
      action = nil
    when "policy_sim"
      if params[:action] == "policies"
        partial = "vm_common/policies"
        header = _("%s Policy Simulation") % ui_lookup(:table => table)
        action = nil
      else
        partial = "layouts/policy_sim"
        header = _("%s Policy Simulation") % ui_lookup(:table => table)
        action = nil
      end
    when "protect"
      partial = "layouts/protect"
      header = _("%s Policy Assignment") % ui_lookup(:table => table)
      action = "protect"
    when "reconfigure"
      partial = "vm_common/reconfigure"
      header = _("Reconfigure %s") % ui_lookup(:table => table)
      action = "reconfigure_update"
    when "retire"
      partial = "shared/views/retire"
      header = _("Set/Remove retirement date for %s") % ui_lookup(:table => table)
      action = "retire"
    when "right_size"
      partial = "vm_common/right_size"
      header = _("Right Size Recommendation for %{model} \"%{name}\"") % {:name=>name, :model=>ui_lookup(:table => table)}
      action = nil
    when "tag"
      partial = "layouts/tagging"
      header = _("Edit Tags for %s") % ui_lookup(:table => table)
      action = "tagging_edit"
    when "snapshot_add"
      partial = "vm_common/snap"
      header = _("Adding a new %s") % ui_lookup(:model => "Snapshot")
      action = "snap_vm"
    when "timeline"
      partial = "layouts/tl_show"
      header = _("Timelines for %{model} \"%{name}\"") % {:model=>ui_lookup(:table => table), :name=>name}
      x_history_add_item(:id=>x_node, :text=>header, :button=>params[:pressed])
      action = nil
    else
    # now take care of links on summary screen
      if ["details","ontap_storage_volumes","ontap_file_shares","ontap_logical_disks","ontap_storage_systems"].include?(@showtype)
        partial = "layouts/x_gtl"
      elsif @showtype == "item"
        partial = "layouts/item"
      elsif @showtype == "drift_history"
        partial = "layouts/#{@showtype}"
      else
        partial = "#{@showtype == "compliance_history" ? "shared/views" : "vm_common"}/#{@showtype}"
      end
      if @showtype == "item"
        header = _("%{action} \"%{item_name}\" for %{model} \"%{name}\"") % {:model=>ui_lookup(:table => table), :name=>name, :item_name=>@item.kind_of?(ScanHistory) ? @item.started_on.to_s : @item.name, :action=>Dictionary::gettext(@sb[:action], :type=>:ui_action, :notfound=>:titleize).singularize}
        x_history_add_item(:id=>x_node, :text=>header, :action=>@sb[:action], :item=>@item.id)
      else
        header = _("\"%{action}\" for %{model} \"%{name}\"") % {:model=>ui_lookup(:table => table), :name=>name, :action=>Dictionary::gettext(@sb[:action], :type=>:ui_action, :notfound=>:titleize)}
        if @display && @display != "main"
          x_history_add_item(:id=>x_node, :text=>header, :display=>@display)
        else
          x_history_add_item(:id=>x_node, :text=>header, :action=>@sb[:action]) if @sb[:action] != "drift_history"
        end
      end
      action = nil
    end
    return partial,action,header
  end

  def get_vm_child_selection
    if params["right.x"] || params[:button] == "right"
      if params[:kids_chosen] == nil
        add_flash(_("No %s were selected to move right") % "VMs", :error)
      else
        kids = @edit[:new][:kids].invert
        params[:kids_chosen].each do |kc|
          if @edit[:new][:kids].has_value?(kc.to_i)
            @edit[:choices][kids[kc.to_i]] = kc.to_i
            @edit[:new][:kids].delete(kids[kc.to_i])
          end
        end
      end
    elsif params["left.x"] || params[:button] == "left"
      if params[:choices_chosen] == nil
        add_flash(_("No %s were selected to move left") % "VMs", :error)
      else
        kids = @edit[:choices].invert
        params[:choices_chosen].each do |cc|
          if @edit[:choices].has_value?(cc.to_i)
            @edit[:new][:kids][kids[cc.to_i]] = cc.to_i
            @edit[:choices].delete(kids[cc.to_i])
          end
        end
      end
    elsif params["allright.x"] || params[:button] == "allright"
      if @edit[:new][:kids].length == 0
        add_flash(_("No child VMs to move right, no action taken"), :error)
      else
        @edit[:new][:kids].each do |key, value|
          @edit[:choices][key] = value
        end
        @edit[:new][:kids].clear
      end
    end
  end

  # Get variables from edit form
  def get_form_vars
    @record = VmOrTemplate.find_by_id(@edit[:vm_id])
    @edit[:new][:custom_1] = params[:custom_1] if params[:custom_1]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:parent] = params[:chosen_parent].to_i if params[:chosen_parent]
    #if coming from explorer
    get_vm_child_selection if ["allright","left","right"].include?(params[:button])
  end

  # Build the audit object when a record is saved, including all of the changed fields
  def build_saved_vm_audit(vm)
    msg = "[#{vm.name} -- #{vm.location}] Record saved ("
    event = "vm_genealogy_change"
    i = 0
    @edit[:new].each_key do |k|
      if @edit[:new][k] != @edit[:current][k]
        msg = msg + ", " if i > 0
        i += 1
        if k == :kids
        #if @edit[:new][k].is_a?(Hash)
          msg = msg +  k.to_s + ":[" + @edit[:current][k].keys.join(",") + "] to [" + @edit[:new][k].keys.join(",") + "]"
        elsif k == :parent
          msg = msg +  k.to_s + ":[" + @edit[:pchoices].invert[@edit[:current][k]] + "] to [" + @edit[:pchoices].invert[@edit[:new][k]] + "]"
        else
          msg = msg +  k.to_s + ":[" + @edit[:current][k].to_s + "] to [" + @edit[:new][k].to_s + "]"
        end
      end
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>vm.id, :target_class=>vm.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  # get the sort column for the detail lists that was clicked on, else use the current one
  def get_detail_sort_col
    if params[:page]==nil && params[:type] == nil && params[:searchtag] == nil    # paging, gtltype change, or search tag did not come in
      if params[:sortby] == nil # no column clicked, reset to first column, ascending
        @detail_sortcol = 0
        @detail_sortdir = "ASC"
      else
        if @detail_sortcol == params[:sortby].to_i                        # if same column was selected
          @detail_sortdir = @detail_sortdir == "ASC" ? "DESC" : "ASC"     #   switch around ascending/descending
        else
          @detail_sortdir = "ASC"
        end
        @detail_sortcol = params[:sortby].to_i
      end
    end

    # in case sort column is not set, set the defaults
    if @detail_sortcol == nil
      @detail_sortcol = 0
      @detail_sortdir = "ASC"
    end

    return @detail_sortcol
  end

  # Gather up the vm records from the DB
  def get_vms(selected=nil)

    page = params[:page] == nil ? 1 : params[:page].to_i
    @current_page = page
    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    if selected                             # came in with a list of selected ids (i.e. checked vms)
      @record_pages, @records = paginate(:vms, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir, :conditions=>["id IN (?)", selected])
    else                                      # getting ALL vms
      @record_pages, @records = paginate(:vms, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
    end

  end

  def identify_record(id, klass = self.class.model)
    record = super
    # Need to find the unauthorized record if in explorer
    if record.nil? && @explorer
      record = klass.find_by_id(from_cid(id))
      @unauthorized = true unless record.nil?
    end
    record
  end

  def update_buttons(locals)
    locals[:continue_button] = locals[:submit_button] = false
    locals[:continue_button] = true if @edit[:buttons].include?(:continue)
    locals[:submit_button] = true if @edit[:buttons].include?(:submit)
  end
end
