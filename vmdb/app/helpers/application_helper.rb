module ApplicationHelper
  include_concern 'Dialogs'
  include_concern 'PageLayouts'
  include Sandbox
  include CompressedIds

  # From http://www.juixe.com/techknow/index.php/2006/07/15/acts-as-taggable-tag-cloud
  #   which refers to http://blog.craz8.com/articles/2005/10/28/acts_as_taggable-is-a-cool-piece-of-code
  def tag_cloud(tags, classes)
    max, min = 0, 0
    tags.each { |t|
      max = t.count.to_i if t.count.to_i > max
      min = t.count.to_i if t.count.to_i < min
    }

    divisor = ((max - min) / classes.size) + 1

    tags.each { |t|
      yield t.name, classes[(t.count.to_i - min) / divisor]
    }
  end

  # Create a hidden div area based on a condition (using for hiding nav panes)
  def hidden_div_if(condition, options = {}, &block)
    options[:style] = "display: none" if condition
    if block_given?
      content_tag(:div, options, &block)
    else
      # TODO: Remove this old open-tag-only way in favor of block style
      tag(:div, options, true)
    end
  end

  # Create a hidden span tag based on a condition (using for hiding nav panes)
  def hidden_span_if(condition, options = {}, &block)
    options[:style] = "display: none" if condition
    if block_given?
      content_tag(:span, options, &block)
    else
      # TODO: Remove this old open-tag-only way in favor of block style
      tag(:span, options, true)
    end
  end

  # Check role based authorization for a UI task
  def role_allows(options={})
    role_id = User.current_user.miq_user_role.try(:id)
    if options[:feature]
      if options[:any]
        auth = User.current_user.role_allows_any?(:identifiers=>[options[:feature]])
      else
        auth = User.current_user.role_allows?(:identifier=>options[:feature])
      end
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{session[:userid]}], role id [#{role_id}], feature identifier [#{options[:feature]}]")
    elsif options[:main_tab]
      tab = MAIN_TAB_FEATURES.select{|t| t.first == options[:main_tab]}.first
      auth = User.current_user.role_allows_any?(:identifiers=>tab.last)
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{session[:userid]}], role id [#{role_id}], main tab [#{options[:main_tab]}]")
    else
      auth = false
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{session[:userid]}], role id [#{role_id}], no main tab or feature passed to role_allows")
    end
    return auth
  end

  # Check group based filtered authorization for a UI task
  def group_allows(options={})
    auth = MiqGroup.allows?(session[:group], :identifier=>options[:identifier])
    $log.debug("Group Authorization #{auth ? "successful" : "failed"} for: userid [#{session[:userid]}], group id [#{session[:group]}], feature identifier [#{options[:identifier]}]")
    return auth
  end

  def model_to_controller(record)
    record.class.base_model.name.underscore
  end

  def controller_to_model
    case self.class.model.to_s
    when "TemplateCloud", "VmCloud", "TemplateInfra", "VmInfra"
      VmOrTemplate
    else
      self.class.model
    end
  end

  def url_for_record(record, action="show") # Default action is show
    @id = to_cid(record.id)
    if record.kind_of?(VmOrTemplate)
      return url_for_db(record.vdi? ? record.class.to_s : controller_for_vm(model_for_vm(record)), action)
    elsif record.kind_of?(ExtManagementSystem)
      return url_for_db(model_for_ems(record).to_s, action)
    else
      return url_for_db(record.class.base_class.to_s, action)
    end
  end

  # Create a url for a record that links to the proper controller
  def url_for_db(db, action="show") # Default action is show
    if @vm && ["Account", "User", "Group", "Patch", "GuestApplication"].include?(db)
      return url_for(:controller => "vm_or_template",
                     :action     => @lastaction,
                     :id         => @vm,
                     :show       => @id
      )
    elsif @host && ["Patch", "GuestApplication"].include?(db)
      return url_for(:controller=>"host", :action=>@lastaction, :id=>@host, :show=>@id)
    elsif db == "MiqCimInstance" && @db && @db == "snia_local_file_system"
      return url_for(:controller=>@record.class.to_s.underscore, :action=>"snia_local_file_systems", :id=>@record, :show=>@id)
    elsif db == "MiqCimInstance" && @db && @db == "cim_base_storage_extent"
      return url_for(:controller=>@record.class.to_s.underscore, :action=>"cim_base_storage_extents", :id=>@record, :show=>@id)
    else
      controller, action = db_to_controller(db, action)
      return url_for(:controller=>controller, :action=>action, :id=>@id)
    end
  end

  # Create a url to show a record from the passed in view
  def view_to_url(view, parent=nil)
    association = view.scoped_association
    # Handle other sub-items of a VM or Host
    case view.db
    when "AdvancedSetting"  then association = "advanced_settings"
    when "Filesystem"       then association = "filesystems"
    when "FirewallRule"     then association = "firewall_rules"
    when "GuestApplication" then association = "guest_applications"
    when "Patch"            then association = "patches"
    when "RegistryItem"     then association = "registry_items"
    when "ScanHistory"      then association = "scan_histories"
    when "SystemService"
      case parent.class.base_class.to_s.downcase
      when "host" then association = "host_services"
      when "vm"   then association = @lastaction
      end
    end
    if association == nil
      controller, action = db_to_controller(view.db)
      if parent && parent.class.base_model.to_s == "MiqCimInstance" && ["CimBaseStorageExtent","SniaLocalFileSystem"].include?(view.db)
        return url_for(:controller=>controller, :action=>action, :id=>parent.id) + "?show="
      else
        if @explorer
          #showing a list view of another CI inside vmx
          if %w(OntapStorageSystem
                OntapLogicalDisk
                OntapStorageVolume
                OntapFileShare
                SecurityGroup).include?(view.db)
            return url_for(:controller=>controller, :action=>"show") + "/"
          elsif ["Vm"].include?(view.db) && parent && request.parameters[:controller] != "vm"
            # this is to handle link to a vm in vm explorer from service explorer
            return url_for(:controller=>"vm_or_template", :action=>"show") + "/"
          else
            return url_for(:action=>action) + "/" # In explorer, don't jump to other controllers
          end
        else
          controller = "vm_cloud" if controller == "template_cloud"
          controller = "vm_infra" if controller == "template_infra"
          return url_for(:controller=>controller, :action=>action) + "/"
        end
      end

    else
      #need to add a check for @explorer while setting controller incase building a link for details screen to show items
      #i.e users list view screen inside explorer needs to point to vm_or_template controller
      return url_for(:controller=>parent.class.base_class.to_s == "VmOrTemplate" && !@explorer ? parent.class.base_model.to_s.underscore : request.parameters["controller"],
                    :action=>association,
                    :id=>parent.id) + "?#{@explorer ? "x_show" : "show"}="
    end
  end

  # Convert a db name to a controller name and an action
  def db_to_controller(db, action = "show")
    action = "x_show" if @explorer
    case db
    when "ActionSet"
      controller = "miq_action"
      action = "show_set"
    when "AutomationRequest"
      controller = "miq_request"
      action = "show"
    when "CimBaseStorageExtent"
      controller = request.parameters[:controller]
      action = "cim_base_storage_extents"
    when "ConditionSet"
      controller = "condition"
    when "ScanItemSet"
      controller = "ops"
      action = "ap_show"
    when "MiqEvent"
      controller = "event"
      action = "_none_"
    when "User", "Group", "Patch", "GuestApplication"
      controller = "vm"
      action = @lastaction
    when "MiqReportResult"
      controller = "report"
      action = "show_saved"
    when "MiqSchedule"
      if request.parameters["controller"] == "report"
        controller = "report"
        action = "show_schedule"
      else
        controller = "ops"
        action = "schedule_show"
      end
    when "MiqAeClass"
      controller = "miq_ae_class"
      action = "show_instances"
    when "MiqAeInstance"
      controller = "miq_ae_class"
      action = "show_details"
    when "MiqCimInstance"
      controller = @view ? @view.db.underscore : @record.class.to_s.underscore
      action = "show"
    when "ProductUpdate"
      controller = "ops"
      action = "show_product_update"
    when "SecurityGroup"
      controller = "security_group"
      action = "show"
    when "ServiceResource", "ServiceTemplate"
      controller = "catalog"
    when "SniaLocalFileSystem"
      controller = request.parameters[:controller]
      action = "snia_local_file_systems"
    when "MiqWorker"
      controller = request.parameters[:controller]
      action = "diagnostics_worker_selected"
    else
      controller = db.underscore
    end
    return controller, action
  end

  # Method to create the center toolbar XML
  def build_toolbar_buttons_and_xml(tb_name)
    text = nil                                                      # Local vars for text and title
    title = nil
    tb_hash = tb_name == "custom_buttons_tb" ? build_custom_buttons_toolbar(@record) : YAML::load(File.open("#{TOOLBARS_FOLDER}/#{tb_name}.yaml"))
    # Add custom buttons hash to tb button_groups array
    #custom_hash = custom_buttons_hash(@record) if @record && @lastaction == "show" &&
    # tb_name.ends_with?("center_tb") &&
    # ( (@button_group && ["vm"].include?(@button_group)) ||
    #   tb_name.starts_with?("miq_template_") ||
    #   tb_name.starts_with?("ems_cluster_") ||
    #   tb_name.starts_with?("host_") ||
    #   tb_name.starts_with?("storage_") ||
    #   tb_name.starts_with?("management_system_"))

    tb_buttons = Hash.new                                           # Hash to hold button info
    tb_xml = MiqXml.createDoc(nil)                                  # XML to configure the toolbar
    root = tb_xml.add_element('toolbar')
    groups_added = Array.new
    sep_needed = false
    #if custom_hash
      #custom_hash.each do |ch|
      # tb_hash[:button_groups].push(ch)
      #end
    #end
    tb_hash[:button_groups].each_with_index do |bg, bg_idx|         # Go thru all of the button groups
      sep_added = false
      sep_node = false
      if @button_group && (!bg[:name].starts_with?(@button_group + "_") &&
        !bg[:name].starts_with?("custom") && !bg[:name].starts_with?("dialog") &&
        !bg[:name].starts_with?("miq_dialog") && !bg[:name].starts_with?("custom_button") &&
        !bg[:name].starts_with?("instance_") && !bg[:name].starts_with?("image_")) &&
        !["record_summary","summary_main","summary_download","tree_main",
          "x_edit_view_tb","history_main"].include?(bg[:name])
        next      # Skip if button_group doesn't match
      else
        # keeping track of groups that were not skipped to add separator, else it adds a separator before a button even tho no other groups were shown, i.e. vm sub screens, drift_history
        groups_added.push(bg_idx)
      end
      bg[:items].each do |bgi|                                      # Go thru all of the button group items
        if bgi.has_key?(:buttonSelect)                              # buttonSelect node found
          bs_children = false
          props = {"id"=>bgi[:buttonSelect],
                              "type"=>"buttonSelect",
                              "img"=>"#{bgi[:image] ? bgi[:image] : bgi[:buttonSelect]}.png",
                              "imgdis"=>"#{bgi[:image] ? bgi[:image] : bgi[:buttonSelect]}.png"}
          props["title"] = bgi[:title] unless bgi[:title].blank?
          props["text"] = CGI.escapeHTML("#{bgi[:text]}") unless bgi[:text].blank?
          if bgi[:buttonSelect] == "history_choice" && x_tree_history.length < 2
            props["enabled"] = false  # Show disabled history button if no history
          else
            props["enabled"] = "#{bgi[:enabled]}" unless bgi[:enabled].blank?
          end
          props["openAll"] = true # Open/close the button select on click

          # Add a separator, if needed, before this buttonSelect
          if !sep_added && sep_needed
            if groups_added.include?(bg_idx) && groups_added.length > 1
# Commented following line to get some extra space in our toolbars - FB 15875
#             sep_node = root.add_element("item", {"id"=>"sep_#{bg_idx}", "type"=>"separator"}) # Put separators between button groups
            end
          end

          bs_node = root.add_element("item", props)                 # Add buttonSelect node
          bgi[:items].each_with_index do |bsi, bsi_idx|             # Go thru all of the buttonSelect items
            if bsi.has_key?(:separator)                             # If separator found, add it
              props = {"id"=>"sep_#{bg_idx.to_s}_#{bsi_idx.to_s}", "type"=>"separator"}
            else
              next if bsi[:image] == 'pdf' && !PdfGenerator.available?
              next if build_toolbar_hide_button(bsi[:pressed] || bsi[:button])  # Use pressed, else button name
              bs_children = true
              props = {"id"=>bgi[:buttonSelect] + "__" + bsi[:button],
                                  "type"=>"button",
                                  "img"=>"#{bsi[:image] ? bsi[:image] : bsi[:button]}.png",
                                  "imgdis"=>"#{bsi[:image] ? bsi[:image] : bsi[:button]}.png"}
              if bsi[:button].starts_with?("history_")
                if x_tree_history.length > 1
                  props["text"] = CGI.escapeHTML(x_tree_history[bsi[:button].split("_").last.to_i][:text])
                end
              else
                eval("text = \"#{bsi[:text]}\"") unless bsi[:text].blank? # Evaluate substitutions in text
                props["text"] = CGI.escapeHTML("#{text}") unless bsi[:text].blank?
              end
              props["enabled"] = "#{bsi[:enabled]}" unless bsi[:enabled].blank?
              dis_title = build_toolbar_disable_button(bsi[:button])
              props["enabled"] = "false" if dis_title
              bsi[:title] = dis_title if dis_title
              eval("title = \"#{bsi[:title]}\"") unless bsi[:title].blank?  # Evaluate substitutions in text
              props["title"] = dis_title.is_a?(String) ? CGI.escapeHTML(dis_title) : CGI.escapeHTML("#{title}")
            end
            bs_node.add_element("item", props)                      # Add buttonSelect child button node
            build_toolbar_save_button(tb_buttons, bsi, bgi[:buttonSelect]) if bsi[:button]  # Save if a button (not sep)
          end
          build_toolbar_save_button(tb_buttons, bgi) if bs_children || bgi[:buttonSelect] == "history_choice"
          unless bs_children                                        # No children?
            bs_node.remove! if bs_node
# Commented following line to get some extra space in our toolbars - FB 15882
#           sep_node.remove! if sep_node                            # Remove the separator if it was added for this node
          else
            sep_added = true                                        # Separator has officially been added
            sep_needed = true                                       # Need a separator from now on
          end
        elsif bgi.has_key?(:button)                                 # button node found
          next if bgi[:image] == 'pdf' && !PdfGenerator.available?
          button_hide = build_toolbar_hide_button(bgi[:button])
          if button_hide
            # These buttons need to be present even if hidden as we show/hide them dynamically
            next unless ["perf_refresh","perf_reload",
                        "vm_perf_refresh","vm_perf_reload",
                        "timeline_txt","timeline_csv","timeline_pdf",
                        "usage_txt","usage_csv","usage_pdf","usage_reportonly"
                        ].include?(bgi[:button])
          end
          sep_needed = true unless button_hide
          props = {"id"=>bgi[:button],
                              "type"=>"button",
                              "img"=>"#{get_image(bgi[:image],bgi[:button]) ? get_image(bgi[:image],bgi[:button]) : bgi[:button]}.png",
                              "imgdis"=>"#{bgi[:image] ? bgi[:image] : bgi[:button]}.png"}
          props["enabled"] = "#{bgi[:enabled]}" unless bgi[:enabled].blank?
          props["enabled"] = "false" if dis_title = build_toolbar_disable_button(bgi[:button]) || button_hide
          props["text"] = CGI.escapeHTML("#{bgi[:text]}") unless bgi[:text].blank?
          #set pdf button to be hidden if graphical summary screen is set by default
          bgi[:hidden] = ["download_view","vm_download_pdf"].include?(bgi[:button]) &&
                         @settings[:views][:dashboards] == "graphical" ? true : button_hide
          eval("title = \"#{bgi[:title]}\"") if !bgi[:title].blank? # Evaluate substitutions in text
          props["title"] = dis_title.is_a?(String) ? dis_title : title

          # Add a separator, if needed, before this button
          if !sep_added && sep_needed
            if groups_added.include?(bg_idx) && groups_added.length > 1
              root.add_element("item", {"id"=>"sep_#{bg_idx}", "type"=>"separator"})  # Put separators between buttons
              sep_added = true
            end
          end
          sep_needed = true                                         # Button was added, need separators from now on

          root.add_element("item", props)                           # Add button node
          build_toolbar_save_button(tb_buttons, bgi)                # Save button in buttons hash
        elsif bgi.has_key?(:buttonTwoState)                         # two state button node found
          next if build_toolbar_hide_button(bgi[:buttonTwoState])
          props = {"id"=>bgi[:buttonTwoState],
                              "type"=>"buttonTwoState",
                              "img"=>"#{bgi[:image] ? bgi[:image] : bgi[:buttonTwoState]}.png",
                              "imgdis"=>"#{bgi[:image] ? bgi[:image] : bgi[:buttonTwoState]}.png"}
          eval("title = \"#{bgi[:title]}\"") unless bgi[:title].blank?
          props["title"] = bgi[:title] unless bgi[:title].blank?
          props["enabled"] = "#{bgi[:enabled]}" unless bgi[:enabled].blank?
          props["enabled"] = "false" if build_toolbar_disable_button(bgi[:buttonTwoState])
          props["selected"] = "true" if build_toolbar_select_button(bgi[:buttonTwoState])
          if !sep_added && sep_needed
            if groups_added.include?(bg_idx) && groups_added.length > 1
              root.add_element("item", {"id"=>"sep_#{bg_idx}", "type"=>"separator"})  # Put separators between buttons
              sep_added = true
            end
          end
          sep_needed = true                                         # Button was added, need separators from now on

          root.add_element("item", props)                           # Add button node
          build_toolbar_save_button(tb_buttons, bgi)                # Save button in buttons hash
        end
      end
    end

    return tb_buttons.to_json.html_safe, tb_xml.to_s.html_safe
  end

  def create_custom_button_hash(input, record, options = {})
    options[:enabled]  = "true" unless options.has_key?(:enabled)
    button             = Hash.new
    button_id          = input[:id]
    button_name        = CGI.escapeHTML(input[:name].to_s)
    button[:button]    = "custom__custom_#{button_id}"
    button[:image]     = "custom-#{input[:image]}"
    button[:text]      = button_name if input[:text_display]
    button[:title]     = CGI.escapeHTML(input[:description].to_s)
    button[:enabled]   = options[:enabled]
    button[:url]       = "button"
    button[:url_parms] = "?id=#{record.id}&button_id=#{button_id}&cls=#{record.class.to_s}&pressed=custom_button&desc=#{button_name}"
    button
  end

  def create_raw_custom_button_hash(cb, record)
    obj = Hash.new
    obj[:id]            = cb.id
    obj[:class]         = cb.applies_to_class
    obj[:description]   = cb.description
    obj[:name]          = cb.name
    obj[:image]         = cb.options[:button_image]
    obj[:text_display]  = cb.options.has_key?(:display) ? cb.options[:display] : true
    obj[:target_object] = record.id.to_i
    obj
  end

  def custom_buttons_hash(record)
    get_custom_buttons(record).collect do |group|
      props = Hash.new
      props[:buttonSelect] = "custom_#{group[:id]}"
      props[:image]        = "custom-#{group[:image]}"
      props[:title]        = group[:description]
      props[:text]         = group[:text] if group[:text_display]
      props[:enabled]      = "true"
      props[:items]        = group[:buttons].collect { |b| create_custom_button_hash(b, record) }

      { :name => "custom_buttons_#{group[:text]}", :items => [props] }
    end
  end

  def build_custom_buttons_toolbar(record)
    toolbar_hash = { :button_groups => custom_buttons_hash(record) }

    service_buttons = record_to_service_buttons(record)
    unless service_buttons.empty?
      h =  {
             :name  => "custom_buttons_",
             :items => service_buttons.collect { |b| create_custom_button_hash(b, record, :enabled => nil) }
           }
      toolbar_hash[:button_groups].push(h)
    end

    toolbar_hash
  end

  def button_class_name(record)
    case record
    when Service;      "ServiceTemplate"            # Service Buttons are defined in the ServiceTemplate class
    when VmOrTemplate; record.class.base_model.name
    else               record.class.base_class.name
    end
  end

  def service_template_id(record)
    case record
    when Service;         record.service_template_id
    when ServiceTemplate; record.id
    else                  nil
    end
  end

  def record_to_service_buttons(record)
    return [] unless record.kind_of?(Service)
    return [] if record.service_template.nil?
    record.service_template.custom_buttons.collect { |cb| create_raw_custom_button_hash(cb, record) }
  end

  def get_custom_buttons(record)
    cbses = CustomButtonSet.find_all_by_class_name(button_class_name(record), service_template_id(record))
    cbses.sort { |a,b| a.name <=> b.name }.collect do |cbs|
      group = Hash.new
      group[:id]           = cbs.id
      group[:text]         = cbs.name.split("|").first
      group[:description]  = cbs.description
      group[:image]        = cbs.set_data[:button_image]
      group[:text_display] = cbs.set_data.has_key?(:display) ? cbs.set_data[:display] : true

      available = CustomButton.available_for_user(session[:userid], cbs.name) # get all uri records for this user for specified uri set
      available = available.select { |b| cbs.members.include?(b) }            # making sure available_for_user uri is one of the members
      group[:buttons] = available.collect { |cb| create_raw_custom_button_hash(cb, record) }.uniq
      group
    end
  end

  def get_image(img, b_name)
    # to change summary screen button to green image
    return "summary-green" if b_name == "show_summary" && ["scan_profile","miq_schedule","miq_proxy"].include?(@layout)
    img
  end

  def build_toolbar_hide_button_rsop(id)
    case id
    when 'toggle_collapse' then !@sb[:rsop][:open]
    when 'toggle_expand'   then @sb[:rsop][:open]
    end
  end

  def build_toolbar_hide_button_cb(id)
    case x_active_tree
      when :cb_reports_tree
        if role_allows(:feature=>"chargeback_reports") && ["chargeback_download_csv","chargeback_download_pdf",
            "chargeback_download_text", "chargeback_report_only"].include?(id)
          return false
        end
      when :cb_rates_tree
        if role_allows(:feature=>"chargeback_rates") && ["chargeback_rates_copy","chargeback_rates_delete",
            "chargeback_rates_edit", "chargeback_rates_new"].include?(id)
          return false
        end
    end
    return true
  end

  def build_toolbar_hide_button_ops(id)
    case x_active_tree
      when :settings_tree
        return ["schedule_run_now"].include?(id) ? true : false
      when :diagnostics_tree
        case @sb[:active_tab]
          when "diagnostics_audit_log"
            return ["fetch_audit_log","refresh_audit_log"].include?(id) ? false : true
          when "diagnostics_collect_logs"
            return %(collect_current_logs collect_logs log_depot_edit
                     zone_collect_current_logs zone_collect_logs
                     zone_log_depot_edit).include?(id) ? false : true
          when "diagnostics_evm_log"
            return ["fetch_log","refresh_log"].include?(id) ? false : true
          when "diagnostics_production_log"
            return ["fetch_production_log","refresh_production_log"].include?(id) ? false : true
          when "diagnostics_roles_servers","diagnostics_servers_roles"
            case id
            when "reload_server_tree"
              return false
            when "delete_server", "zone_delete_server"
              return @record.class == MiqServer ? false : true
            when "role_start", "role_suspend", "zone_role_start", "zone_role_suspend"
              return @record.class == AssignedServerRole && @record.miq_server.started? ? false : true
            when "demote_server", "promote_server", "zone_demote_server", "zone_promote_server"
              return @record.class == AssignedServerRole && @record.master_supported? ? false : true
            end
            return true
          when "diagnostics_summary"
            return ["refresh_server_summary","restart_server"].include?(id) ? false : true
          when "diagnostics_workers"
            return ["refresh_workers","restart_workers"].include?(id) ? false : true
          else
            return true
        end
      when :rbac_tree
        return false
      when :vmdb_tree
        return ["db_connections","db_details","db_indexes","db_settings"].include?(@sb[:active_tab]) ? false : true
      else
        return true
    end
  end

  def build_toolbar_hide_button_pxe(id)
    case x_active_tree
    when :customization_templates_tree
      return true unless role_allows(:feature => id)
      nodes = x_node.split('-')
      if nodes.first == "root"
        # show only add button on root node
        id == "customization_template_new" ? false : true
      elsif nodes.last == "system" || (@record && @record.system)
        # allow only copy button for system customization templates
        id == "customization_template_copy" ? false : true
      else
        false
      end
    else
      !role_allows(:feature => id)
    end
  end

  def build_toolbar_hide_button_report(id)
    if ["miq_report_copy","miq_report_delete","miq_report_edit","miq_report_new",
        "miq_report_run","miq_report_schedules"].include?(id )
      return true if !role_allows(:feature=>id)
    end
    case x_active_tree
      when :widgets_tree
        case id
          when "widget_new"
            return x_node == "root"
          when "widget_generate_content"
            return @sb[:wtype] == "m"
        end
        return false
      when :reports_tree
        case id
          when "saved_report_delete", "reload"
            return @sb[:active_tab] == "saved_reports" ? false : true
          when "miq_report_edit","miq_report_delete"
            return @sb[:active_tab] == "report_info" && @record.rpt_type == "Custom" ?
                false : true
          when "miq_report_copy","miq_report_new","miq_report_run","miq_report_only","miq_report_schedules"
            return @sb[:active_tab] == "saved_reports"
          when "view_graph","view_hybrid","view_tabular"
            return @ght_type && @report && @report.graph &&
                (@zgraph || (@ght_type == "tabular" && @html)) ? false : true
          return false
        end
      when :savedreports_tree
        case id
          when "reload"
            return x_node == "root" ? false : true
          when "view_graph","view_hybrid","view_tabular"
            return @ght_type && @report && @report.graph &&
                (@zgraph || (@ght_type == "tabular" && @html)) ? false : true
        end
      else
        return false
    end
  end

  # Determine if a button should be hidden
  def build_toolbar_hide_button(id)
    return true if id == "blank_button" # Always hide the blank button placeholder

    # hide timelines button for Amazon provider and instances
    # TODO: extend .is_available? support via refactoring task to cover this scenario
    return true if ['ems_cloud_timeline', 'instance_timeline'].include?(id) && (@record.kind_of?(EmsAmazon) || @record.kind_of?(VmAmazon))

    # hide edit button for MiqRequest instances of type ServiceTemplateProvisionRequest
    # TODO: extend .is_available? support via refactoring task to cover this scenario
    return true if id == 'miq_request_edit' && @miq_request.try(:type) == 'ServiceTemplateProvisionRequest'

    # only hide gtl button if they are not in @temp
    return @temp[:gtl_buttons].include?(id) ? false : true if @temp &&
                                                @temp[:gtl_buttons] && ["view_grid","view_tile","view_list"].include?(id)

    #don't hide view buttons in toolbar
    return false if ["view_grid","view_tile","view_list","refresh_log","fetch_log",
                      "common_drift","download_text", "download_csv", "download_pdf",
                      "view_graphical","view_textual","download_view","vm_download_pdf",
                      "tree_large","tree_small"].include?(id) && !["miq_policy_rsop","ops"].include?(@layout)

    # dont hide back to summary button button when not in explorer
    return false if id == "show_summary" && !@explorer

    #hide vdi buttons if flag is marked true
    if id.starts_with?("vdi_desktop") || id.starts_with?("vdi_user") || id == "vm_mark_vdi"
      return true unless VdiFarm::MGMT_ENABLED
    end

    #need to hide certain buttons when on vdi user/desktop pool direct list view screen.
    if id.starts_with?("vdi_") && @lastaction == "show_list" && !@display
      return true if ["vdi_user_desktop_pool_unassign","vdi_desktop_pool_user_unassign"].include?(id)
    end

    #need to hide import/delete buttons when viewing list of  VdiUsers for desktop pool.
    if id.starts_with?("vdi_") && @lastaction == "show" && @display == "vdi_user"
      return true if ["vdi_user_delete","vdi_user_import"].include?(id)
    end

    #need to hide unmark VDI button if has_broker? is true
    if id.starts_with?("vdi_") && @lastaction == "show" && @display == "vdi_desktop"
      return true if @record.has_broker?
    end

    #need to hide add buttons when on sub-list view screen of a CI.
    return true if (id.ends_with?("_new") || id.ends_with?("_discover")) &&
                            @lastaction == "show" && @display != "main"

    #don't need delete buttons when viewing list of desktop pools for VDI User
    return true if ["vdi_desktop_pool_delete"].include?(id) && request.parameters[:controller] == "vdi_user"

    #don't need these buttons when viewing list of desktop pools for VDI farm
    return true if ["vdi_desktop_pool_user_assign","vdi_desktop_pool_user_unassign"].include?(id) && request.parameters[:controller] == "vdi_farm"

    if id == "summary_reload"                             # Show reload button if
      return @explorer &&                                 # we are in explorer and
             ((@record &&                                 #    1) we are on a record and
              !["miq_policy_rsop"].include?(@layout) &&   # @layout is not one of these
              !["details","item"].include?(@showtype)) || #       not showing list or single sub screen item i.e VM/Users
              @lastaction == "show_list") ?               # or 2) selected node shows a list of records
        false : true
    end

    if id.starts_with?("history_")
      if x_tree_history[id.split("_").last.to_i] || id.ends_with?("_1")
        return false
      else
        return true
      end
    end

    # user can see the buttons if they can get to Policy RSOP/Automate Simulate screen
    return false if ["miq_ae_tools"].include?(@layout)

    #hide this button when in custom buttons tree on ci node, this button is added in toolbar to show on Buttons folder node in CatalogItems tree
    return true if id == "ab_button_new" && x_active_tree == :ab_tree && x_node.split('_').length == 2 &&  x_node.split('_')[0] == "xx-ab"

    # Form buttons don't need RBAC check
    return false if ["button_add"].include?(id) && @edit && !@edit[:rec_id]

    # Form buttons don't need RBAC check
    return false if ["button_save","button_reset"].include?(id) && @edit && @edit[:rec_id]

    # Form buttons don't need RBAC check
    return false if ["button_cancel"].include?(id)

    #buttons on compare/drift screen are allowed if user has access to compare/drift
    return false if id.starts_with?("compare_") || id.starts_with?("drift_") || id.starts_with?("comparemode_") || id.starts_with?("driftmode_")

    # Allow custom buttons on CI show screen, user can see custom button if they can get to show screen
    return false if id.starts_with?("custom_")

    return false if id == "miq_request_reload" && # Show the request reload button
      (@lastaction == "show_list" || @showtype == "miq_provisions")

    if @layout == "miq_policy_rsop"
      return build_toolbar_hide_button_rsop(id)
    end

    if id.starts_with?("chargeback_")
      res = build_toolbar_hide_button_cb(id)
      return res
    end

    if @layout == "ops"
      res = build_toolbar_hide_button_ops(id)
      return res
    end

    if @layout == "pxe" || id.starts_with?("pxe_") || id.starts_with?("customization_template_")
      res = build_toolbar_hide_button_pxe(id)
      return res
    end

    if @layout == "report"
      res = build_toolbar_hide_button_report(id)
      return res
    end

    return false if role_allows(:feature=>"my_settings_time_profiles") && @layout == "configuration" &&
                      @tabform == "ui_4"

    return false if id.starts_with?("miq_capacity_") && @sb[:active_tab] == "report"

    #hide button if id is approve/deny and miq_request_approval feature is not allowed.
    return true if !role_allows(:feature=>"miq_request_approval") && ["miq_request_approve","miq_request_deny"].include?(id)

    # don't check for feature RBAC if id is miq_request_approve/deny
    if @layout != "miq_policy"
      return true if !role_allows(:feature=>id) && !["miq_request_approve","miq_request_deny"].include?(id) &&
          !id.starts_with?("dialog_") && !id.starts_with?("miq_task_")
    end
    # Check buttons with other restriction logic
    case id
    when "dialog_add_box", "dialog_add_element", "dialog_add_tab", "dialog_res_discard", "dialog_resource_remove"
      return true if !@edit
      return true if id == "dialog_res_discard" && @sb[:edit_typ] != "add"
      return true if id == "dialog_resource_remove" && (@sb[:edit_typ] == "add" || x_node == "root")
      nodes = x_node.split('_')
      return true if id == "dialog_add_tab" && (nodes.length > 2)
      return true if id == "dialog_add_box" && (nodes.length < 2 || nodes.length > 3)
      return true if id == "dialog_add_element" && (nodes.length < 3 || nodes.length > 4)
    when "dialog_copy", "dialog_delete", "dialog_edit", "dialog_new"
      return true if @edit && @edit[:current]
    when "miq_task_canceljob"
      return true if !["all_tasks", "all_ui_tasks"].include?(@layout)
    when "vm_console", "vm_vdi_console"
      return true if !@record.console_supported? ||
          (get_vmdb_config[:server][:remote_console_type] && get_vmdb_config[:server][:remote_console_type] != "MKS")
    when "vm_vnc_console", "vm_vdi_vnc_console"
      return true if !@record.console_supported? ||
          !get_vmdb_config[:server][:remote_console_type] ||
          (get_vmdb_config[:server][:remote_console_type] && get_vmdb_config[:server][:remote_console_type] != "VNC")
    when "vm_vmrc_console", "vm_vdi_vmrc_console"
      return true if !@record.console_supported? ||
          !get_vmdb_config[:server][:remote_console_type] ||
          (get_vmdb_config[:server][:remote_console_type] && get_vmdb_config[:server][:remote_console_type] != "VMRC")
    # Check buttons behind SMIS setting
    when "ontap_storage_system_statistics", "ontap_logical_disk_statistics", "ontap_storage_volume_statistics",
        "ontap_file_share_statistics"
      return true unless get_vmdb_config[:product][:smis]
    when 'vm_publish'
      return true if @is_redhat
    end

    # Now check model/record specific rules
    case get_record_cls(@record)
    when "AssignedServerRole"
      case id
      when "delete_server"
        return true
      end
    when "Condition"
      case id
      when "condition_edit"
        return true if !role_allows(:feature => "condition_edit")
      when "condition_copy"
        return true if x_active_tree != :condition_tree || !role_allows(:feature => "condition_new")
      when "condition_delete"
        return true if x_active_tree != :condition_tree || !role_allows(:feature => "condition_delete")
      when "condition_policy_copy"
        return true if x_active_tree == :condition_tree || !role_allows(:feature => "condition_new")
      when "condition_remove"
        return true if x_active_tree == :condition_tree || !role_allows(:feature => "condition_delete")
      end
    when "Host"
      case id
      when "host_protect"
        return true if !@record.smart?
      when "host_refresh"
        return true if !@record.is_refreshable?
      when "host_scan"
        return true if !@record.is_scannable?
      when "host_shutdown", "host_standby", "host_reboot",
          "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"
        btn_id = id.split("_")[1..-1].join("_")
        return true if !@record.is_available?(btn_id.to_sym)
      when "perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "MiqAction"
      case id
      when "action_edit"
        return true if !role_allows(:feature=>"action_edit")
      when "action_delete"
        return true if !role_allows(:feature=>"action_delete")
      end
    when "MiqAeClass", "MiqAeField", "MiqAeInstance", "MiqAeMethod", "MiqAeNamespace"
      case id
      when "miq_ae_domain_lock"
        return true unless @record.editable?
      when "miq_ae_domain_unlock"
        return true if @record.editable? || @record.priority.to_i == 0
      else
        return true unless @record.editable?
      end
    when "MiqAlert"
      case id
      when "alert_copy"
        return true if !role_allows(:feature => "alert_copy")
      when "alert_edit"
        return true if !role_allows(:feature=>"alert_edit")
      when "alert_delete"
        return true if !role_allows(:feature=>"alert_delete")
      end
    when "MiqAlertSet"
      case id
      when "alert_profile_edit"
        return true if !role_allows(:feature=>"alert_profile_edit")
      when "alert_profile_delete"
        return true if !role_allows(:feature=>"alert_profile_delete")
      end
    when "MiqEvent"
      case id
      when "event_edit"
        return true if x_active_tree == :event_tree || !role_allows(:feature => "event_edit")
      end
    when "MiqPolicy"
      case id
      when "condition_edit", "policy_edit", "policy_edit_conditions"
        return true if !role_allows(:feature=>"policy_edit")
      when "policy_edit_conditions"
        return true if !role_allows(:feature => "policy_edit_conditions")
      when "policy_edit_events"
        return true if !role_allows(:feature=>"policy_edit") ||
            @policy.mode == "compliance"
      when "policy_copy"
        return true if !role_allows(:feature=>"policy_copy") ||
            x_active_tree != :policy_tree
      when "policy_delete"
        return true if !role_allows(:feature=>"policy_delete") ||
            x_active_tree != :policy_tree
      end
    when "MiqPolicySet"
      case id
      when "profile_edit"
        return true unless role_allows(:feature => "profile_edit")
      when "profile_delete"
        return true unless role_allows(:feature => "profile_delete")
      end
    when "MiqProxy"
      case id
      when "miq_proxy_edit"
        return true if params[:action] == "log_viewer"
      when "miq_proxy_deploy"
        return true if !@record.host.smart? || params[:action] == "log_viewer"
      end
    when "MiqProvisionRequest", "MiqHostProvisionRequest", "VmReconfigureRequest",
        "VmMigrateRequest", "AutomationRequest", "ServiceTemplateProvisionRequest"

      # Don't hide certain buttons on AutomationRequest screen
      return true if @record.resource_type == "AutomationRequest" &&
          !["miq_request_approve", "miq_request_deny", "miq_request_delete"].include?(id)

      case id
      when "miq_request_approve", "miq_request_deny"
        return true if ["approved", "denied"].include?(@record.approval_state) || @showtype == "miq_provisions"
      when "miq_request_delete"
        requester = User.find_by_userid(session[:userid])
        return true if requester.name != @record.requester_name || ["approved", "denied"].include?(@record.approval_state)
      when "miq_request_edit"
        requester = User.find_by_userid(session[:userid])
        return true if requester.name != @record.requester_name || ["approved", "denied"].include?(@record.approval_state)
      when "miq_request_copy"
        requester = User.find_by_userid(session[:userid])
        return true if !["MiqProvisionRequest", "MiqHostProvisionRequest"].include?(@record.resource_type) || ((requester.name != @record.requester_name || ["approved", "denied"].include?(@record.approval_state)) && @showtype == "miq_provisions")
      end
    when "MiqServer", "MiqRegion"
      case id
      when "role_start", "role_suspend", "promote_server", "demote_server"
        return true
      when "log_download", "refresh_logs", "log_collect", "log_reload", "logdepot_edit", "processmanager_restart", "refresh_workers"
        return true
      end
    when "ScanItemSet"
      case id
      when "scan_delete"
        return true if @record.read_only
      when "scan_edit"
        return true if @record.read_only
      end
    when "ServerRole"
      case id
      when "server_delete", "role_start", "role_suspend", "promote_server", "demote_server"
        return true
      end
    when "Vm"
      case id
      when "vm_clone", "vm_publish"
        return true if @record.vendor.downcase == "redhat"
      when "vm_collect_running_processes", "vm_vdi_collect_running_processes"
        return true if (@record.retired || @record.current_state == "never") && !@record.is_available?(:collect_running_processes)
      when "vm_evm_relationship", "vm_right_size"
        return true if @record.vdi?
      when "vm_guest_startup", "vm_start", "vm_vdi_guest_startup", "vm_vdi_power_on", "instance_start", "instance_resume"
        return true if !@record.is_available?(:start)
      when "vm_guest_standby", "vm_vdi_guest_standby"
        return true if !@record.is_available?(:standby_guest)
      when "vm_guest_shutdown", "vm_vdi_guest_shutdown", "instance_guest_shutdown"
        return true if !@record.is_available?(:shutdown_guest)
      when "vm_guest_restart", "vm_vdi_guest_restart", "instance_guest_restart"
        return true if !@record.is_available?(:reboot_guest)
      when "vm_migrate", "vm_reconfigure"
        return true if @record.vendor.downcase == "redhat" || @record.vdi?
      when "vm_stop", "vm_vdi_power_off", "instance_stop"
        return true if !@record.is_available?(:stop)
      when "vm_reset", "vm_vdi_power_reset", "instance_reset"
        return true if !@record.is_available?(:reset)
      when "vm_suspend", "vm_vdi_power_suspend", "instance_suspend"
        return true if !@record.is_available?(:suspend)
      when "instance_pause"
        return true if !@record.is_available?(:pause)
      when "vm_policy_sim", "vm_protect", "vm_vdi_policy_sim", "vm_vdi_protect"
        return true if @record.host && @record.host.vmm_product.to_s.downcase == "workstation"
      when "vm_refresh", "vm_vdi_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "vm_scan", "vm_vdi_scan"
        return true if !@record.has_proxy?
      when "perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "MiqTemplate"
      case id
      when "miq_template_clone"
        return true if @record.vendor.downcase == "redhat"
      when "miq_template_policy_sim", "miq_template_protect"
        return true if @record.host && @record.host.vmm_product.downcase == "workstation"
      when "miq_template_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "miq_template_scan"
        return true if !@record.has_proxy?
      when "miq_template_refresh", "miq_template_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "VdiDesktop"
      case id
      when "vdi_desktop_unmark_vdi"
        return true if @record.vdi_desktop_pool && @record.vdi_desktop_pool.has_broker?
      end
    when "VdiDesktopPool"
      case id
      when "vdi_desktop_pool_manage_desktops"
        return true if @record.has_broker?
      end
    when "NilClass"
      case id
      when "action_new"
        return true if !role_allows(:feature => "action_new")
      when "alert_profile_new"
        return true if !role_allows(:feature=>"alert_profile_new")
      when "alert_new"
        return true if !role_allows(:feature => "alert_new")
      when "condition_new"
        return true if !role_allows(:feature=>"condition_new")
      when "log_download"
        return true if ["workers", "download_logs"].include?(@lastaction)
      when "log_collect"
        return true if ["workers", "evm_logs", "audit_logs"].include?(@lastaction)
      when "log_reload"
        return true if ["workers", "download_logs"].include?(@lastaction)
      when "logdepot_edit"
        return true if ["workers", "evm_logs", "audit_logs"].include?(@lastaction)
      when "policy_new"
        return true unless role_allows(:feature => "policy_new")
      when "profile_new"
        return true unless role_allows(:feature => "profile_new")
      when "processmanager_restart"
        return true if ["download_logs", "evm_logs", "audit_logs"].include?(@lastaction)
      when "refresh_workers"
        return true if ["download_logs", "evm_logs", "audit_logs"].include?(@lastaction)
      when "refresh_logs"
        return true if ["audit_logs", "evm_logs", "workers"].include?(@lastaction)
      when "usage_txt"
        return true if !@usage_options[:report] || (@usage_options[:report] && @usage_options[:report].table.data.length <= 0)
      when "usage_csv"
        return true if !@usage_options[:report] || (@usage_options[:report] && @usage_options[:report].table.data.length <= 0)
      when "usage_pdf"
        return true if !@usage_options[:report] || (@usage_options[:report] && @usage_options[:report].table.data.length <= 0)
      when "usage_reportonly"
        return true if !@usage_options[:report] || (@usage_options[:report] && @usage_options[:report].table.data.length <= 0)
      when "timeline_csv"
        return true if !@report
      when "timeline_pdf"
        return true if !@report
      when "timeline_txt"
        return true if !@report
      end
    end
    return false  # No reason to hide, allow the button to show
  end

  # Determine if a button should be disabled
  def build_toolbar_disable_button(id)
    return true if id.starts_with?("view_") && id.ends_with?(@settings[:views][:dashboards])  # Summary view buttons
    return true if @gtl_type && id.starts_with?("view_") && id.ends_with?(@gtl_type)  # GTL view buttons
    return true if id == "history_1" && x_tree_history.length < 2 # Need 1 child button to show parent

    # Form buttons check if anything on form has changed
    return true if ["button_add","button_save","button_reset"].include?(id) && !@changed

    #need to add this here, since this button is on list view screen
    if @layout == "pxe" && id == "iso_datastore_new"
      return "No #{ui_lookup(:tables => "ext_management_system")} are available to create an ISO Datastore on" if EmsRedhat.find(:all).delete_if{|e| e.iso_datastore != nil}.count <= 0
    end

    case get_record_cls(@record)
    when "AssignedServerRole"
      case id
      when "role_start"
        if x_node != "root" && @record.server_role.regional_role?
          return "This role can only be managed at the Region level"
        elsif @record.active
          return "This Role is already active on this Server"
        elsif !@record.miq_server.started? && !@record.active
          return "Only available Roles on active Servers can be started"
        end
      when "role_suspend"
        if x_node != "root" && @record.server_role.regional_role?
          return "This role can only be managed at the Region level"
        else
          if @record.active
            unless @record.server_role.max_concurrent != 1
              return "Activate the #{@record.server_role.description} Role on another Server to suspend it on #{@record.miq_server.name} [#{@record.miq_server.id}]"
            end
          else
            return "Only active Roles on active Servers can be suspended"
          end
        end
      when "demote_server"
        if @record.master_supported?
          if @record.priority == 1 || @record.priority == 2
            if x_node != "root" && @record.server_role.regional_role?
              return "This role can only be managed at the Region level"
            end
          end
        end
      when "promote_server"
        if @record.master_supported?
          if (@record.priority != 1 && @record.priority != 2) || @record.priority == 2
            if x_node != "root" && @record.server_role.regional_role?
              return "This role can only be managed at the Region level"
            end
          end
        end
      end
    when "AvailabilityZone"
      case id
      when "availability_zone_perf"
        return "No Capacity & Utilization data has been collected for this Availability Zone" unless @record.has_perf_data?
      when "availability_zone_timeline"
        return "No Timeline data has been collected for this Availability Zone" unless @record.has_events? #|| @record.has_events?(:policy_events), may add this check back in later
      end
    when "OntapStorageSystem"
      case id
      when "ontap_storage_system_statistics"
        return "No Statistics Collected" unless @record.latest_derived_metrics
      end
    when "OntapLogicalDisk"
      case id
      when "ontap_logical_disk_perf"
        return "No Capacity & Utilization data has been collected for this Logical Disk" unless @record.has_perf_data?
      when "ontap_logical_disk_statistics"
        return "No Statistics collected for this Logical Disk" unless @record.latest_derived_metrics
      end
    when "CimBaseStorageExtent"
      case id
      when "cim_base_storage_extent_statistics"
        return "No Statistics Collected" unless @record.latest_derived_metrics
      end
    when "Condition"
      case id
      when "condition_delete"
        return "Conditions assigned to Policies can not be deleted" if @condition.miq_policies.length > 0
      end
    when "OntapStorageVolume"
      case id
      when "ontap_storage_volume_statistics"
        return "No Statistics Collected" unless @record.latest_derived_metrics
      end
    when "OntapFileShare"
      case id
      when "ontap_file_share_statistics"
        return "No Statistics Collected" unless @record.latest_derived_metrics
      end
    when "SniaLocalFileSystem"
      case id
      when "snia_local_file_system_statistics"
        return "No Statistics Collected" unless @record.latest_derived_metrics
      end
    when "EmsCluster"
      case id
      when "ems_cluster_perf"
        return "No Capacity & Utilization data has been collected for this Cluster" unless @record.has_perf_data?
      when "ems_cluster_timeline"
        return "No Timeline data has been collected for this Cluster" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "Host"
      case id
      when "host_analyze_check_compliance", "host_check_compliance"
        return "No Compliance Policies assigned to this Host" unless @record.has_compliance_policies?
      when "host_perf"
        return "No Capacity & Utilization data has been collected for this Host" unless @record.has_perf_data?
      when "host_miq_request_new"
        return "This Host can not be provisioned because the MAC address is not known" if !@record.mac_address
        count = PxeServer.all.size
        return "No PXE Servers are available for Host provisioning" if count <= 0
      when "host_refresh"
        return @record.is_refreshable_now_error_message if !@record.is_refreshable_now?
      when "host_scan"
        return @record.is_scannable_now_error_message if !@record.is_scannable_now?
      when "host_timeline"
        return "No Timeline data has been collected for this Host" unless @record.has_events? || @record.has_events?(:policy_events)
      when "host_shutdown"
        return @record.is_available_now_error_message(:shutdown) if @record.is_available_now_error_message(:shutdown)
      when "host_restart"
        return @record.is_available_now_error_message(:reboot) if @record.is_available_now_error_message(:reboot)
      end
    when "MiqProxy"
      case id
      when "miq_proxy_deploy"
        if !@record.host.state.blank? && @record.host.state != "on"
          return "The SmartProxy can not be managed because the Host is not powered on"
        else
          if @record.host.available_builds.length == 0
            return "Host OS is unknown or there are no available SmartProxy versions for the Host's OS"
          end
        end
      end
    when "MiqAction"
      case id
      when "action_edit"
        return "Default actions can not be changed." if @record.action_type == "default"
      when "action_delete"
        return "Default actions can not be deleted." if @record.action_type == "default"
        return "Actions assigned to Policies can not be deleted" if @record.miq_policies.length > 0
      end
    when "MiqAeNamespace"
      case id
      when "miq_ae_domain_delete"
        return "Read Only Domain cannot be deleted." unless @record.editable?
      when "miq_ae_domain_edit"
        return "Read Only Domain cannot be edited" unless @record.editable?
      when "miq_ae_domain_lock"
        return "Domain is Locked." unless @record.editable?
      when "miq_ae_domain_unlock"
        return "Domain is Unlocked." if @record.editable?
      end
    when "MiqAlert"
      case id
      when "alert_delete"
        return "Alerts that belong to Alert Profiles can not be deleted" if @record.memberof.length > 0
        return "Alerts referenced by Actions can not be deleted" if @record.owning_miq_actions.length > 0
      end
    when "MiqPolicy"
      case id
      when "policy_delete"
        return "Policies that belong to Profiles can not be deleted" if @policy.memberof.length > 0
      end
    when "MiqGroup"
      case id
      when "rbac_group_delete"
        return "This Group is Read Only and can not be deleted" if @record.read_only
      when "rbac_group_edit"
        return "This Group is Read Only and can not be edited" if @record.read_only
      end
    when "MiqServer"
      case id
      when "collect_logs", "collect_current_logs"
        return "Cannot collect current logs unless the #{ui_lookup(:table=>"miq_servers")} is started" if @record.status != "started"
        return "Log collection is already in progress for this #{ui_lookup(:table=>"miq_servers")}" if @record.log_collection_active_recently?
        return "Log collection requires the Log Depot settings to be configured" if !@record.log_depot_configured? && !@record.zone.log_depot_configured?
      when "delete_server"
        return "Server #{@record.name} [#{@record.id}] can only be deleted if it is stopped or has not responded for a while" if !@record.is_deleteable?
      when "restart_workers"
        return "Select a worker to restart" if @sb[:selected_worker_id].nil?
      end
    when "MiqWidget"
      case id
      when "widget_generate_content"
        return "Widget has to be assigned to a dashboard to generate content" if @record.memberof.count <= 0
        return "This Widget content generation is already running or queued up" if @temp[:widget_running]
      end
    when "MiqWidgetSet"
      case id
      when "db_delete"
        return "Default Dashboard cannot be deleted" if @db.read_only
      end
    when "Service"
      case id
      when "service_retire_now"
        return "Service is already retired" if @record.retired == true
      end
    when "ScanItemSet"
      case id
      when "ap_delete"
        return "Sample Analysis Profile cannot be deleted" if @record.read_only
      when "ap_edit"
        return "Sample Analysis Profile cannot be edited" if @record.read_only
      end
    when "ServiceTemplate"
      case id
      when "svc_catalog_provision"
        d = nil
        @record.resource_actions.each do |ra|
          d = Dialog.find_by_id(ra.dialog_id.to_i) if ra.action.downcase == "provision"
        end
        return "No Ordering Dialog is available" if d.nil?
      end
    when "Storage"
      case id
      when "storage_perf"
        return "No Capacity & Utilization data has been collected for this #{ui_lookup(:table=>"storages")}" unless @record.has_perf_data?
      when "storage_delete"
        return "Only #{ui_lookup(:table=>"storages")} without VMs and Hosts can be removed" if @record.vms_and_templates.length > 0 || @record.hosts.length > 0
      end
    when "User"
      case id
      when "rbac_user_copy"
        return "User [Administrator] can not be copied" if @record.userid == "admin"
      when "rbac_user_delete"
        return "User [Administrator] can not be deleted" if @record.userid == "admin"
      end
    when "UserRole"
      case id
      when "rbac_role_delete"
        return "This Role is Read Only and can not be deleted" if @record.read_only
        return "This Role is in use by one or more Groups and can not be deleted" if @record.group_count > 0
      when "rbac_role_edit"
        return "This Role is Read Only and can not be edited" if @record.read_only
      end
    when "Vm"
      case id
      when "vm_perf", "vm_vdi_perf"
        return "No Capacity & Utilization data has been collected for this VM" unless @record.has_perf_data?
      when "instance_check_compliance", "vm_check_compliance"
        model = model_for_vm(@record).to_s
        return "No Compliance Policies assigned to this #{model == "VmInfra" ? "VM" : ui_lookup(:model => model)}" unless @record.has_compliance_policies?
      when "vm_collect_running_processes", "vm_vdi_collect_running_processes"
        return @record.is_available_now_error_message(:collect_running_processes) if @record.is_available_now_error_message(:collect_running_processes)
      when "vm_console", "vm_vdi_console", "vm_vmrc_console", "vm_vdi_vmrc_console"
        if !is_browser?(%w(explorer firefox mozilla)) ||
          !is_browser_os?(%w(windows linux))
          return "The web-based console is only available on IE, Firefox or Chrome (Windows/Linux)"
        end

        if id.in?(["vm_vmrc_console", "vm_vdi_vmrc_console"])
          begin
            @record.validate_remote_console_vmrc_support
          rescue MiqException::RemoteConsoleNotSupportedError => err
            return "VM VMRC Console error: #{err}"
          end
        end

        return "The web-based console is not available because the VM is not powered on" if @record.current_state != "on"
      when "vm_vnc_console", "vm_vdi_vnc_console"
        return "The web-based VNC console is not available because the VM is not powered on" if @record.current_state != "on"
      when "vm_guest_startup", "vm_start", "vm_vdi_guest_startup", "vm_vdi_start"
        return @record.is_available_now_error_message(:start) if @record.is_available_now_error_message(:start)
      when "vm_guest_standby", "vm_vdi_guest_standby"
        return @record.is_available_now_error_message(:standby_guest) if @record.is_available_now_error_message(:standby_guest)
      when "vm_guest_shutdown", "vm_vdi_guest_shutdown"
        return @record.is_available_now_error_message(:shutdown_guest) if @record.is_available_now_error_message(:shutdown_guest)
      when "vm_guest_restart", "vm_vdi_guest_restart"
        return @record.is_available_now_error_message(:reboot_guest) if @record.is_available_now_error_message(:reboot_guest)
      when "vm_mark_vdi"
        return "This VM is already a VDI Desktop" if @record.vdi?
      when "vm_stop", "vm_vdi_stop"
        return @record.is_available_now_error_message(:stop) if @record.is_available_now_error_message(:stop)
      when "vm_reset", "vm_vdi_reset"
        return @record.is_available_now_error_message(:reset) if @record.is_available_now_error_message(:reset)
      when "vm_suspend", "vm_vdi_suspend"
        return @record.is_available_now_error_message(:suspend) if @record.is_available_now_error_message(:suspend)
      when "instance_retire", "instance_retire_now",
              "vm_retire", "vm_retire_now",
              "vm_vdi_retire","vm_vdi_retire_now"
        return "#{@record.kind_of?(VmCloud) ? "Instance" : "VM"} is already retired" if @record.retired == true
      when "vm_scan", "vm_vdi_scan"
        return @record.active_proxy_error_message if !@record.has_active_proxy?
      when "vm_timeline", "vm_vdi_timeline"
        return "No Timeline data has been collected for this VM" unless @record.has_events? || @record.has_events?(:policy_events)
      when "vm_snapshot_add", "vm_vdi_snapshot_add"
        if @record.number_of(:snapshots) <= 0
          return @record.is_available_now_error_message(:create_snapshot) unless @record.is_available?(:create_snapshot)
        else
          unless @record.is_available?(:create_snapshot)
            return @record.is_available_now_error_message(:create_snapshot)
          else
            return "Select the Active snapshot to create a new snapshot for this VM" unless @active
          end
        end
      when "vm_snapshot_delete", "vm_vdi_snapshot_delete"
        return @record.is_available_now_error_message(:remove_snapshot) unless @record.is_available?(:remove_snapshot)
      when "vm_snapshot_delete_all", "vm_vdi_snapshot_delete_all"
        return @record.is_available_now_error_message(:remove_all_snapshots) unless @record.is_available?(:remove_all_snapshots)
      when "vm_snapshot_revert", "vm_vdi_snapshot_revert"
        return @record.is_available_now_error_message(:revert_to_snapshot) unless @record.is_available?(:revert_to_snapshot)
      end
    when "MiqTemplate"
      case id
      when "image_check_compliance","miq_template_check_compliance"
        return "No Compliance Policies assigned to this #{ui_lookup(:model => model_for_vm(@record).to_s)}" unless @record.has_compliance_policies?
      when "miq_template_perf"
        return "No Capacity & Utilization data has been collected for this Template" unless @record.has_perf_data?
      when "miq_template_scan"
        return @record.active_proxy_error_message if !@record.has_active_proxy?
      when "miq_template_timeline"
        return "No Timeline data has been collected for this Template" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "VdiDesktop"
      case id
      when "vdi_desktop_user_assign"
        return @record.supports_user_assignment_error_message
      end
    when "VdiUser"
      case id
      when "vdi_user_import"
        return "No LDAP Servers available for import" if LdapServer.find(:all).size <= 0
      end
    when "Zone"
      case id
      when "collect_logs", "collect_current_logs"
        return "Cannot collect current logs unless there are started #{ui_lookup(:tables=>"miq_servers")} in the Zone" if @record.miq_servers.collect { |s| s.status == "started" ? true : nil }.compact.length == 0
        return "This Zone and one or more active #{ui_lookup(:tables=>"miq_servers")} in this Zone do not have Log Depot settings configured, collection not allowed" if !@record.log_depot_configured? && @record.miq_servers.collect { |s| s.log_depot_configured? ? true : nil }.compact.length == 0
        return "Log collection is already in progress for one or more #{ui_lookup(:tables=>"miq_servers")} in this Zone" if @record.log_collection_active_recently?
      when "zone_delete"
        if @selected_zone.name.downcase == "default"
          return "'Default' zone cannot be deleted"
        elsif @selected_zone.ext_management_systems.count > 0 ||
            @selected_zone.storage_managers.count > 0 ||
            @selected_zone.vdi_farms.count > 0 ||
            @selected_zone.miq_schedules.count > 0 ||
            @selected_zone.miq_servers.count > 0
          return "Cannot delete a Zone that has Relationships"
        end
      end
    when nil, "NilClass"
      case id
      when "ab_group_edit"
        return "Selected Custom Button Group cannot be edited" if x_node.split('-')[1] == "ub"
      when "ab_group_delete"
        return "Selected Custom Button Group cannot be deleted" if x_node.split('-')[1] == "ub"
      when "ab_group_reorder"
        if x_active_tree == :ab_tree
          return "Only more than 1 Custom Button Groups can be reordered" if CustomButtonSet.find_all_by_class_name(x_node.split('_').last).count <= 1
        else
          rec_id = x_node.split('_').last.split('-').last
          st = ServiceTemplate.find_by_id(rec_id)
          count = st.custom_button_sets.count + st.custom_buttons.count
          return "Only more than 1 Custom Button Groups can be reordered" if count <= 1
        end
      when "ae_copy_simulate"
        return "Object attribute must be specified to copy object details for use in a Button" if @resolve[:button_class].blank?
      when "customization_template_new"
        return "No System Image Types available, Customization Template cannot be added" if @temp[:pxe_image_types_count] <= 0
      #following 2 are checks for buttons in Reports/Dashboard accordion
      when "db_new"
        return "Only #{MAX_DASHBOARD_COUNT} Dashboards are allowed for a group" if @temp[:widgetsets].length >= MAX_DASHBOARD_COUNT
      when "db_seq_edit"
        return "There should be atleast 2 Dashboards to Edit Sequence" if @temp[:widgetsets].length <= 1
      when "miq_capacity_download_csv", "miq_capacity_download_pdf", "miq_capacity_download_text"
        if (x_active_tree == nil && @sb[:planning] && @sb[:planning][:rpt] && !@sb[:planning][:rpt].table.data.empty?) ||
            (x_active_tree == :utilization_tree && @sb[:util] && @sb[:util][:trend_rpt] && @sb[:util][:summary])
          return false
        else
          return "No records found for this report"
        end
      when "render_report_csv", "render_report_pdf",
          "render_report_txt", "report_only"
        if (@html || @zgraph) && (!@report.extras[:grouping] || (@report.extras[:grouping] && @report.extras[:grouping][:_total_][:count] > 0))
          return false
        else
          return "No records found for this report"
        end
      end
    when 'MiqReportResult'
      if id == 'report_only'
        return @report.present? && @report_result_id.present? &&
            MiqReportResult.find(@report_result_id).try(:miq_report_result_details).try(:length).to_i > 0 ? false : "No records found for this report"
      end
    end
    false
  end

  def get_record_cls(record)
    if record.kind_of?(AvailabilityZone)
      record.class.base_class.name
    else
      klass = case record
              when Host, ExtManagementSystem; record.class.base_class
              when VmOrTemplate;              record.class.base_model
              else                            record.class
              end
      klass.name
    end
  end

  # Determine if a button should be selected for buttonTwoState
  def build_toolbar_select_button(id)
    return true if id.starts_with?("view_") && id.ends_with?(@settings[:views][:dashboards])  # Summary view buttons
    return true if @gtl_type && id.starts_with?("view_") && id.ends_with?(@gtl_type)  # GTL view buttons
    return true if @ght_type && id.starts_with?("view_") && id.ends_with?(@ght_type)  # GHT view buttons on report show
    return true if id.starts_with?("tree_") && id.ends_with?(@settings[:views][:treesize].to_i == 32 ? "large" : "small")
    return true if id.starts_with?("compare_") && id.ends_with?(@settings[:views][:compare])
    return true if id.starts_with?("drift_") && id.ends_with?(@settings[:views][:drift])
    return true if id == "compare_all"
    return true if id == "drift_all"
    return true if id.starts_with?("comparemode_") && id.ends_with?(@settings[:views][:compare_mode])
    return true if id.starts_with?("driftmode_") && id.ends_with?(@settings[:views][:drift_mode])
    return false
  end

  # Save a button tb_buttons hash
  def build_toolbar_save_button(tb_buttons, item, parent = nil)
    confirm_title = nil
    parms = nil
    url = nil
    title = nil
    button = item.has_key?(:buttonTwoState) ? item[:buttonTwoState] : (item.has_key?(:buttonSelect) ? item[:buttonSelect] : item[:button])
    button = parent + "__" + button if parent # Prefix with "parent__" if parent is passed in
    tb_buttons[button] = Hash.new
    tb_buttons[button][:name] = button
    tb_buttons[button][:pressed] = item[:pressed] if item[:pressed]
    tb_buttons[button][:hidden] = item[:hidden] ? true : false
    eval("title = \"#{item[:title]}\"") if parent && item[:title]
    tb_buttons[button][:title] = title if parent && item[:title]
    eval("url = \"#{item[:url]}\"") if item[:url]
    if ["view_grid","view_tile","view_list"].include?(tb_buttons[button][:name])
      # blows up in sub screens for CI's, need to get rid of first directory and anything after last slash in @gtl_url, that's being manipulated in JS function
      url.gsub!(/^\/[a-z|A-Z|0-9|_|-]+/,"")
      ridx = url.rindex('/') if url
      url = url.slice(0..ridx-1)  if ridx
    end
    tb_buttons[button][:url] = url if item[:url]
    tb_buttons[button][:explorer] = true if @explorer && !item[:url]  # Add explorer = true if ajax button
    if item[:popup]
      tb_buttons[button][:popup] = item[:popup]
      if item[:url_parms] == "popup_only" # For readonly reports, they don't have confirm message
        tb_buttons[button][:console_url] = "/#{request.parameters["controller"]}#{item[:url]}"
      else    # Assuming at this point this is a console button
        if item[:url] == "vnc_console"  # This is a VNC console button
          tb_buttons[button][:console_url] = "http://#{@record.ipaddresses[0]}:#{get_vmdb_config[:server][:vnc_port]}"
        else  # This is an MKS or VMRC VMware console button
          tb_buttons[button][:console_url] = "/#{request.parameters["controller"]}#{item[:url]}/#{@record.id}"
        end
      end
    end
    eval("parms = \"#{item[:url_parms]}\"") if item[:url_parms]
    tb_buttons[button][:url_parms] = parms if item[:url_parms]
    # doing eval for ui_lookup in confirm message
    eval("confirm_title = \"#{item[:confirm]}\"") if item[:confirm]
    tb_buttons[button][:confirm] = confirm_title if item[:confirm]
    tb_buttons[button][:onwhen] = item[:onwhen] if item[:onwhen]
  end

  def get_console_url
    return url = @record.hostname ? @record.hostname : @record.ipaddress
  end

  # Convert a field (Vm.hardware.disks-size) to a col (disks.size)
  def field_to_col(field)
    dbs, fld = field.split("-")
    return (dbs.include?(".") ? "#{dbs.split(".").last}.#{fld}": fld)
  end

  # Get the dynamic list of tags for the expression atom editor
  def exp_available_tags(model, use_mytags = false)
    # Generate tag list unless already generated during this transaction
    @exp_available_tags ||= MiqExpression.model_details(model, :typ=>"tag",
                                                    :include_model=>true,
                                                    :include_my_tags=>use_mytags,
                                                    :userid => session[:userid])
    return @exp_available_tags
  end

  #Replacing calls to VMDB::Config.new in the views/controllers
  def get_vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  # Derive the browser title text based on the layout value
  def title_from_layout(layout)
    title = I18n.t('product.name')
    if layout.blank?  # no layout, leave title alone
    elsif ["configuration", "dashboard", "chargeback", "about"].include?(layout)
      title += ": #{layout.titleize}"

    # Specific titles for certain layouts
    elsif layout == "miq_proxy"
      title += ": SmartProxies"
    elsif layout == "miq_server"
      title += ": Servers"
    elsif layout == "usage"
      title += ": VM Usage"
    elsif layout == "scan_profile"
      title += ": Analysis Profiles"
    elsif layout == "miq_policy_rsop"
      title += ": Policy Simulation"
    elsif layout == "all_ui_tasks"
      title += ": All UI Tasks"
    elsif layout == "rss"
      title += ": RSS"
    elsif layout == "storage_manager"
      title += ": Storage - Storage Managers"
    elsif layout == "ops"
      title += ": Configuration"
    elsif layout == "pxe"
      title += ": PXE"
    elsif layout == "explorer"
      title += ": #{controller_model_name(params[:controller])} Explorer"
    elsif layout == "vm_cloud"
      title += ": Instances"
    elsif layout == "vm_infra"
      title += ": Virtual Machines"
    elsif layout == "vm_or_template"
      title += ": Workloads"
    # Specific titles for groups of layouts
    elsif layout.starts_with?("miq_ae_")
      title += ": Automate"
    elsif layout.starts_with?("miq_policy")
      title += ": Control"
    elsif layout.starts_with?("miq_capacity")
      title += ": Optimize"
    elsif layout.starts_with?("miq_request")
      title += ": Requests"
    elsif layout.starts_with?("vdi_")
      title += ": VDI - #{ui_lookup(:tables=>layout)}"
    elsif layout.starts_with?("cim_") ||
          layout.starts_with?("snia_")
      title += ": Storage - #{ui_lookup(:tables=>layout)}"

    # Assume layout is a table name and look up the plural version
    else
      title += ": #{ui_lookup(:tables=>layout)}"
    end
    return title
  end

  def controller_model_name(controller)
    ui_lookup(:model=>(controller.camelize + "Controller").constantize.model.name)
  end

  def is_browser_ie?
    browser_info(:name).downcase == "explorer"
  end

  def is_browser_ie7?
    is_browser_ie? && browser_info(:version).starts_with?("7")
  end

  def is_browser?(name)
    browser_name = browser_info(:name).downcase
    name.kind_of?(Array) ? name.include?(browser_name) : (browser_name == name)
  end

  def is_browser_os?(os)
    browser_os = browser_info(:os).downcase
    os.kind_of?(Array) ? os.include?(browser_os) : (browser_os == os)
  end

  def browser_info(typ = :name)
    session.fetch_path(:browser, typ.to_sym).to_s
  end

  ############# Following methods generate JS lines for render page blocks
  def javascript_for_timer_type(timer_type)
    js_array = []
    unless timer_type.nil?
      case timer_type
      when "Monthly"
        js_array << "$('weekly_span').hide();"
        js_array << "$('daily_span').hide();"
        js_array << "$('hourly_span').hide();"
        js_array << "$('monthly_span').show();"
      when "Weekly"
        js_array << "$('daily_span').hide();"
        js_array << "$('hourly_span').hide();"
        js_array << "$('monthly_span').hide();"
        js_array << "$('weekly_span').show();"
      when "Daily"
        js_array << "$('hourly_span').hide();"
        js_array << "$('monthly_span').hide();"
        js_array << "$('weekly_span').hide();"
        js_array << "$('daily_span').show();"
      when "Hourly"
        js_array << "$('daily_span').hide();"
        js_array << "$('monthly_span').hide();"
        js_array << "$('weekly_span').hide();"
        js_array << "$('hourly_span').show();"
      else
        js_array << "$('daily_span').hide();"
        js_array << "$('hourly_span').hide();"
        js_array << "$('monthly_span').hide();"
        js_array << "$('weekly_span').hide();"
      end
    end
    js_array
  end

  # Show/hide the Save and Reset buttons based on whether changes have been made
  def javascript_for_miq_button_visibility(display)
    "miqButtons('#{display ? 'show' : 'hide'}');".html_safe
  end

  def javascript_for_miq_button_visibility_changed(changed)
    return "" if changed == session[:changed]
    session[:changed] = changed
    javascript_for_miq_button_visibility(changed)
  end

  # Highlight tree nodes that have been changed
  def javascript_for_tree_checkbox_clicked(tree_name)
    tree_name_escaped = j_str(tree_name)
    js_array = []
    if params[:check] # Tree checkbox clicked?
      # MyCompany tag checked or Belongsto checked
      key = params[:tree_typ] == 'myco' ? :filters : :belongsto
      future  = @edit[:new    ][key][params[:id].split('___').last]
      current = @edit[:current][key][params[:id].split('___').last]
      css_class = future == current ? 'dynatree-title' : 'cfme-blue-bold-node'
      js_array << "$j('##{tree_name_escaped}box').dynatree('getTree').getNodeByKey('#{params[:id].split('___').last}').data.addClass = '#{css_class}';"
    end
    # need to redraw the tree to change node colors
    js_array << "tree = $j('##{tree_name_escaped}box').dynatree('getTree');"
    js_array << "tree.redraw();"
    js_array.join("\n")
  end

  # Reload toolbars using new buttons object and xml
  def javascript_for_toolbar_reload(tb, buttons, xml)
    js = ""
    js << "#{tb}.unload();"
    js << "#{tb} = null;"
    js << "#{tb} = new dhtmlXToolbarObject('#{tb}', 'miq_blue');"
    js << "miq_toolbars.set('#{tb}', $H({obj:#{tb}, buttons:#{buttons}, xml:\"#{xml}\"}));" # Store hash of object, buttons, and xml
    js << "miqInitToolbar(miq_toolbars.get('#{tb}'));"
    return js
  end

  # Generate lines of JS <text> for render page, replacing "~" with the <sub_array> elements
  def js_multi_lines(sub_array, text)
    js_array = []
    sub_array.each do |i|
      js_array << text.gsub("~", i.to_s)
    end
    js_array
  end

  def javascript_set_value(element_id, value)
    "$j('##{element_id}').val('#{value}');"
  end
  ############# End of methods that generate JS lines for render page blocks

  def set_edit_timer_from_schedule(schedule)
    t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
    @edit[:new][:timer_months ] = "1"
    @edit[:new][:timer_weeks ]  = "1"
    @edit[:new][:timer_days]    = "1"
    @edit[:new][:timer_hours]   = "1"
    if schedule.run_at.nil?
      @edit[:new][:timer_typ]    = "Once"
      @edit[:new][:start_hour]   = "00"
      @edit[:new][:start_min]    = "00"
    else
      @edit[:new][:timer_typ]    = schedule.run_at[:interval][:unit].titleize
      @edit[:new][:timer_months] = schedule.run_at[:interval][:value] if schedule.run_at[:interval][:unit] == "monthly"
      @edit[:new][:timer_weeks]  = schedule.run_at[:interval][:value] if schedule.run_at[:interval][:unit] == "weekly"
      @edit[:new][:timer_days]   = schedule.run_at[:interval][:value] if schedule.run_at[:interval][:unit] == "daily"
      @edit[:new][:timer_hours]  = schedule.run_at[:interval][:value] if schedule.run_at[:interval][:unit] == "hourly"
      t                          = schedule.run_at[:start_time].to_time.in_time_zone(@edit[:tz])
      @edit[:new][:start_hour]   = t.strftime("%H")
      @edit[:new][:start_min]    = t.strftime("%M")
    end
    @edit[:new][:start_date] = "#{t.month}/#{t.day}/#{t.year}"  # Set the start date
  end

  # Check if a parent chart has been selected and applies
  def perf_parent?
    return @perf_options[:model] == "VmOrTemplate" &&
           @perf_options[:typ] != "realtime" &&
           VALID_PERF_PARENTS.keys.include?(@perf_options[:parent])
  end

  # Check if a parent chart has been selected and applies
  def perf_compare_vm?
    return @perf_options[:model] == "OntapLogicalDisk" && @perf_options[:typ] != "realtime" && !@perf_options[:compare_vm].nil?
  end

  # Determine the type of report (performance/trend/chargeback) based on the model
  def model_report_type(model)
    if model
      if (model.ends_with?("Performance") || model.ends_with?("MetricsRollup"))
        return :performance
      elsif model == UiConstants::TREND_MODEL
        return :trend
      elsif model == "Chargeback"
        return :chargeback
      end
    end
    nil
  end

  def taskbar_in_header?
    if @show_taskbar.nil?
      @show_taskbar = false
      if ! (@layout == ""  &&
      # if ! (@layout == "dashboard"  &&
          ["show","change_tab","auth_error"].include?(controller.action_name) ||
          ["about","rss","server_build","product_update","miq_policy","miq_ae_class",
           "miq_capacity_utilization","miq_capacity_planning","miq_capacity_bottlenecks","miq_capacity_waste","chargeback",
           "miq_ae_export","miq_ae_automate_button","miq_ae_tools","miq_policy_export","miq_policy_rsop","report",
           "ops","pxe","exception"].include?(@layout) || (@layout == "configuration" && @tabform != "ui_4"))
        unless @explorer
          @show_taskbar = true
        end
      end
    end
    return @show_taskbar
  end

  def inner_layout_present?
    if @inner_layout_present.nil?
      @inner_layout_present = false
      if @explorer || params[:action] == "explorer" ||
          (params[:controller] == "chargeback" && params[:action] == "chargeback") ||
          (params[:controller] == "miq_ae_tools" && (params[:action] == "resolve" || params[:action] == "show")) ||
          (params[:controller] == "miq_policy" && params[:action] == "rsop") ||
          (params[:controller] == "miq_capacity")
        @inner_layout_present = true
      end
    end
    return @inner_layout_present
  end

  # Format a column in a report view for display on the screen
  def format_col_for_display(view, row, col, tz = nil)
    tz ||= ["miqschedule"].include?(view.db.downcase) ? MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC" : Time.zone
    celltext = view.format(col,
                           row[col],
                           :tz=>tz
    ).gsub(/\\/, '\&')    # Call format, then escape any backslashes
    celltext.gsub!(/(['""<>\n\r\t]{1})/,'\\\\\&')                   # Now escape special characters
    return celltext
  end

  # Only show the background image with listnav splitter for some classic screens
  def show_page_content_background
    return false if @layout == "exception"
    return true if params[:action] == "timeline"
    if ["show", "show_list", "show_timeline", "new", "edit",
        "protect", "tagging_edit", "discover", "compare_miq", "drift_history", "drift",
        "users", "groups", "patches","firewall_rules", "usage",
        "host_services", "advanced_settings", "guest_applications", "filesystems",
        "assign","user_import","perf_top_chart"
       ].include?(params[:action])
      unless ["miq_request", "dashboard", "alert"].include?(params[:controller])
        return true
      end
    end
    return false
  end

  # Truncate text to fit below a quad icon
  TRUNC_AT = 13
  TRUNC_TO = 10
  def truncate_for_quad(value)
    return value if value.to_s.length < TRUNC_AT
    case @settings[:display][:quad_truncate]
    when "b"  # Old version, used first x chars followed by ...
      return value[0...TRUNC_TO] + "..."
    when "f"  # Chop off front
      return "..." + value[(value.length - TRUNC_TO)..-1]
    else      # Chop out the middle
      numchars = TRUNC_TO / 2
      return value[0...numchars] + "..." + value[(value.length - numchars)..-1]
    end
  end

  def url_for_item_quad_text(record, id, action)
    url_for(:controller => model_to_controller(record),
            :action     => action,
            :id         => record.id.to_s,
            :show       => id.to_s)
  end

  CUSTOM_TOOLBAR_CONTROLLERS = [
      "service",
      "vm_cloud",
      "vm_infra",
      "vm_or_template"
  ]
  # Return a blank tb if a placeholder is needed for AJAX explorer screens, return nil if no custom toolbar to be shown
  def custom_toolbar_filename
    if ["ems_cloud","ems_cluster","ems_infra","host","miq_template","storage"].include?(@layout)  # Classic CIs
      return "custom_buttons_tb" if @record && @lastaction == "show" && @display == "main"
    end

    if @explorer && CUSTOM_TOOLBAR_CONTROLLERS.include?(params[:controller])
      if x_tree            # Make sure we have the trees defined
        if x_node == "root" || # If on a root, create placeholder toolbar
           !@record                                                  #   or no record showing
          return "blank_view_tb"
        elsif @display == "main"
          return "custom_buttons_tb"
        else
          return "blank_view_tb"
        end
      end
    end

    return nil
  end

  # Return a blank tb if a placeholder is needed for AJAX explorer screens, return nil if no center toolbar to be shown
  def center_toolbar_filename
    if @explorer
      return center_toolbar_filename_explorer
    else
      return center_toolbar_filename_classic
    end
  end

  # Return explorer based toolbar file name
  def center_toolbar_filename_explorer
    if @record && @button_group &&
        !["catalogs","chargeback","miq_capacity_utilization","miq_capacity_planning","services"].include?(@layout)
      if @record.kind_of?(VmCloud)
        return "x_vm_cloud_center_tb"
      elsif @record.kind_of?(TemplateCloud)
        return "x_template_cloud_center_tb"
      else
        return "x_#{@button_group}_center_tb"
      end
    else
      if ["vm_cloud","vm_infra","vm_or_template"].include?(@layout)
        if @record
          if @display == "performance"
            return "vm_performance_tb"
          end
        else
          return  case x_active_tree
                  when :images_filter_tree,:images_tree ;         "template_clouds_center_tb"
                  when :instances_filter_tree, :instances_tree ;  "vm_clouds_center_tb"
                  when :templates_images_filter_tree ;            "miq_templates_center_tb"
                  when :templates_filter_tree ;                   "template_infras_center_tb"
                  when :vms_filter_tree, :vandt_tree ;            "vm_infras_center_tb"
                  when :vms_instances_filter_tree ;               "vms_center_tb"
                  end
        end
      elsif @layout == "miq_policy_rsop"
        return session[:rsop_tree] ? "miq_policy_rsop_center_tb" : "blank_view_tb"
      else
        if x_active_tree == :ae_tree
          return center_toolbar_filename_automate
        elsif [:sandt_tree, :svccat_tree, :stcat_tree, :svcs_tree].include?(x_active_tree)
          return center_toolbar_filename_services
        elsif @layout == "chargeback"
          return center_toolbar_filename_chargeback
        elsif @layout == "miq_ae_tools"
          return session[:userrole] == "super_administrator" ? "miq_ae_tools_simulate_center_tb" : "blank_view_tb"
        elsif @layout == "miq_policy"
          return center_toolbar_filename_miq_policy
        elsif @layout == "ops"
          return center_toolbar_filename_ops
        elsif @layout == "pxe"
          return center_toolbar_filename_pxe
        elsif @layout == "report"
          return center_toolbar_filename_report
        elsif @layout == "miq_ae_customization"
          return center_toolbar_filename_automate_customization
        end
      end
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_automate
    nodes = x_node.split('-')
    return case nodes.first
           when "root" then "miq_ae_domains_center_tb"
           when "aen"  then domain_or_namespace_toolbar(nodes.last)
           when "aec"  then case @sb[:active_tab]
                            when "methods" then  "miq_ae_methods_center_tb"
                            when "props"   then  "miq_ae_class_center_tb"
                            when "schema"  then  "miq_ae_fields_center_tb"
                            else                 "miq_ae_instances_center_tb"
                            end
           when "aei"  then "miq_ae_instance_center_tb"
           when "aem"  then "miq_ae_method_center_tb"
           end
  end

  def domain_or_namespace_toolbar(node_id)
    ns = MiqAeNamespace.find(from_cid(node_id))
    if ns.domain?
      "miq_ae_domain_center_tb"
    elsif !ns.domain?
      "miq_ae_namespace_center_tb"
    else
      "blank_view_tb"
    end
  end

  def center_toolbar_filename_automate_customization
    if x_active_tree == :old_dialogs_tree && x_node != "root"
      return @dialog ? "miq_dialog_center_tb" : "miq_dialogs_center_tb"
    elsif x_active_tree == :dialogs_tree
      if x_node == "root"
        return "dialogs_center_tb"
      elsif @record && !@in_a_form
        return "dialog_center_tb"
      end
    elsif x_active_tree == :ab_tree
      if x_node != "root"
        nodes = x_node.split('_')
        if nodes.length == 2 && nodes[0] == "xx-ab"
          return "custom_button_set_center_tb"  # CI node is selected
        elsif (nodes.length == 1 && nodes[0].split('-').length == 3 && nodes[0].split('-')[1] == "ub") ||
            (nodes.length == 3 && nodes[0] == "xx-ab")
          return "custom_buttons_center_tb"     # group node is selected
        else
          return "custom_button_center_tb"      # button node is selected
        end
      end
    elsif @in_a_form      # to show buttons on dialog add/edit screens
      return "dialog_center_tb"
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_services
    if x_active_tree == :sandt_tree
      if X_TREE_NODE_PREFIXES[@nodetype] == "ServiceTemplate"
        return "servicetemplate_center_tb"
      elsif @sb[:buttons_node]
        nodes = x_node.split('_')
        if nodes.length == 3 && nodes[2].split('-').first == "xx"
          return "custom_button_set_center_tb"
        elsif nodes.length == 4 && nodes[3].split('-').first == "cbg"
          return "custom_buttons_center_tb"
        else
          return "custom_button_center_tb"
        end
      else
        return "servicetemplates_center_tb"
      end
    elsif x_active_tree == :svccat_tree
      if X_TREE_NODE_PREFIXES[@nodetype] == "ServiceTemplate"
        return "servicetemplate-catalog_center_tb"
      else
        return "servicetemplates-catalogs_center_tb"
      end
    elsif x_active_tree == :stcat_tree
      if X_TREE_NODE_PREFIXES[@nodetype] == "ServiceTemplateCatalog"
        return "servicetemplatecatalog_center_tb"
      else
        return "servicetemplatecatalogs_center_tb"
      end
    elsif x_active_tree == :svcs_tree
      if X_TREE_NODE_PREFIXES[@nodetype] == "Service"
        return "service_center_tb"
      else
        return "services_center_tb"
      end
    end
  end

  def center_toolbar_filename_chargeback
    if @report && x_active_tree == :cb_reports_tree
      return "chargeback_center_tb"
    elsif x_active_tree == :cb_rates_tree && x_node != "root"
      if ["Compute","Storage"].include?(x_node.split('-').last)
        return "chargebacks_center_tb"
      else
        return "chargeback_center_tb"
      end
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_miq_policy
    if @nodetype == "xx"
      if @policies || (@view && @sb[:tree_typ] == "policies")
        return "miq_policies_center_tb"
      elsif @conditions
        return "conditions_center_tb"
      elsif @alert_profiles
        return "miq_alert_profiles_center_tb"
      end
    end
    return case @nodetype
      when "root";
        case x_active_tree
          when :policy_profile_tree;  "miq_policy_profiles_center_tb"
          when :action_tree;          "miq_actions_center_tb"
          when :alert_tree;           "miq_alerts_center_tb"
          else                        "blank_view_tb"
        end
      when "pp";  "miq_policy_profile_center_tb"
      when "p";   "miq_policy_center_tb"
      when "co";  "condition_center_tb"
      when "ev";  "miq_event_center_tb"
      when "a";   "miq_action_center_tb"
      when "al";  "miq_alert_center_tb"
      when "ap";  "miq_alert_profile_center_tb"
      else        "blank_view_tb"
    end
  end

  def center_toolbar_filename_ops
    if x_active_tree == :settings_tree
      if x_node.split('-').last == "msc"
        return "miq_schedules_center_tb"
      elsif x_node.split('-').first == "msc"
        return "miq_schedule_center_tb"
      elsif x_node.split('-').last == "l"
        return "ldap_regions_center_tb"
      elsif x_node.split('-').first == "lr"
        return "ldap_region_center_tb"
      elsif x_node.split('-').first == "ld"
        return "ldap_domain_center_tb"
      elsif x_node.split('-').first == "svr" &&
          @sb[:active_tab] == "settings_maintenance"
        return "product_updates_center_tb"
      elsif x_node.split('-').last == "sis"
        return "scan_profiles_center_tb"
      elsif x_node.split('-').first == "sis"
        return "scan_profile_center_tb"
      elsif x_node.split('-').last == "z"
        return "zones_center_tb"
      elsif x_node.split('-').first == "z" &&
          @sb[:active_tab] != "settings_smartproxy_affinity"
        return "zone_center_tb"
      end
    elsif x_active_tree == :diagnostics_tree
      if x_node == "root"
        return "diagnostics_region_center_tb"
      elsif x_node.split('-').first == "svr"
        return "diagnostics_server_center_tb"
      elsif x_node.split('-').first == "z"
        return "diagnostics_zone_center_tb"
      end
    elsif x_active_tree == :rbac_tree
      if x_node.split('-').last == "g"
        return "miq_groups_center_tb"
      elsif x_node.split('-').first == "g"
        return "miq_group_center_tb"
      elsif x_node.split('-').last == "u"
        return "users_center_tb"
      elsif x_node.split('-').first == "u"
        return "user_center_tb"
      elsif x_node.split('-').last == "ur"
        return "user_roles_center_tb"
      elsif x_node.split('-').first == "ur"
        return "user_role_center_tb"
      end
    elsif x_active_tree == :vmdb_tree
      if x_node
        return "vmdb_tables_center_tb"
      else
        return "vmdb_table_center_tb"
      end
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_report
    if x_active_tree == :db_tree
      node = x_node
      if node == "root" || node == "xx-g"
        return "blank_view_tb"
      elsif node.split('-').length == 3
        return "miq_widget_sets_center_tb"
      else
        return "miq_widget_set_center_tb"
      end
    elsif x_active_tree == :savedreports_tree
      node = x_node
      return  node == "root" || node.split('-').first != "rr" ?
          "saved_reports_center_tb" : "saved_report_center_tb"
    elsif x_active_tree == :reports_tree
      nodes = x_node.split('-')
      if nodes.length == 5
        #on report show
        return "miq_report_center_tb"
      elsif nodes.length == 6
        #on savedreport in reports tree
        return "saved_report_center_tb"
      else
        #on folder node
        return "miq_reports_center_tb"
      end
    elsif x_active_tree == :schedules_tree
      return x_node == "root" ?
          "miq_schedules_center_tb" : "miq_schedule_center_tb"
    elsif x_active_tree == :widgets_tree
      node = x_node
      return node == "root" || node.split('-').length == 2 ?
          "miq_widgets_center_tb" : "miq_widget_center_tb"
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_pxe
    if x_active_tree == :pxe_servers_tree
      if x_node == "root"
        return "pxe_servers_center_tb"
      else
        if x_node.split('-').first == "pi"
          return "pxe_image_center_tb"
        elsif x_node.split('-').first == "wi"
          return "windows_image_center_tb"
        else
          return "pxe_server_center_tb"
        end
      end
    elsif x_active_tree == :customization_templates_tree
      if x_node == "root" ||
          x_node.split('-').length == 3
        # root node or folder node selected
        return "customization_templates_center_tb"
      else
        return "customization_template_center_tb"
      end
    elsif x_active_tree == :pxe_image_types_tree
      if x_node == "root"
        return "pxe_image_types_center_tb"
      else
        return "pxe_image_type_center_tb"
      end
    elsif x_active_tree == :iso_datastores_tree
      if x_node == "root"
        return "iso_datastores_center_tb"
      else
        if x_node.split('-').first == "isi"
          #on image node
          return "iso_image_center_tb"
        else
          return "iso_datastore_center_tb"
        end
      end
    end
    return "blank_view_tb"
  end

  # Return non-explorer based toolbar file name
  def center_toolbar_filename_classic
    # Original non vmx view code follows
    # toolbar buttons on sub-screens
    if ((@lastaction == "show" && @view) ||
        (@lastaction == "show" && @display != "main")) &&
        !@layout.starts_with?("miq_request")
      if @display == "vms" || @display == "all_vms"
        return "vm_infras_center_tb"
      elsif @display == "ems_clusters"
        return "ems_clusters_center_tb"
      elsif @display == "hosts"
        return "hosts_center_tb"
      elsif @display == "images"
        return "template_clouds_center_tb"
      elsif @display == "instances"
        return "vm_clouds_center_tb"
      elsif @display == "miq_templates"
        return "template_infras_center_tb"
      elsif @display == "resource_pools"
        return "resource_pools_center_tb"
      elsif @display == "storages"
        return "storages_center_tb"
      elsif @display == "vdi_desktop_pool" && ["vdi_farm","vdi_user"].include?(request.parameters[:controller])
        return "vdi_desktop_pools_center_tb"
      elsif @display == "vdi_user" && request.parameters[:controller] == "vdi_desktop_pool"
        return "vdi_users_center_tb"
      elsif @display == "vdi_desktop" && ["vdi_farm","vdi_desktop_pool"].include?(request.parameters[:controller])
        return "vdi_desktops_center_tb"
      elsif (@layout == "vm" || @layout == "host") && @display == "performance"
        return "#{@explorer ? "x_" : ""}vm_performance_tb"
      end
    elsif @lastaction == "compare_miq" || @lastaction == "compare_compress"
      return "compare_center_tb"
    elsif @lastaction == "drift_history"
      return "drifts_center_tb"
    elsif @lastaction == "drift"
      return "drift_center_tb"
    else
      #show_list and show screens
      if !@in_a_form
        if ["availability_zone","flavor","ems_cloud","ems_cluster","host","ems_infra","miq_proxy",
            "ontap_file_share","ontap_logical_disk","ontap_storage_system","repository",
            "resource_pool","storage","storage_manager","timeline","usage","vdi_desktop",
            "vdi_desktop_pool","vdi_farm","vdi_user","security_group"].include?(@layout)
          if ["show_list"].include?(@lastaction)
            return "#{@layout.pluralize}_center_tb"
          else
            return "#{@layout}_center_tb"
          end
        elsif @layout == "configuration" && @tabform == "ui_4"
          return "time_profiles_center_tb"
        elsif @layout == "diagnostics"
          return "diagnostics_center_tb"
        elsif @layout == "miq_policy_logs" || @layout == "miq_ae_logs"
          return "logs_center_tb"
        elsif ["miq_request_host","miq_request_vm"].include?(@layout)
          if ["show_list"].include?(@lastaction)
            return "miq_requests_center_tb"
          else
            return "miq_request_center_tb"
          end
        elsif @layout == "vm_vdi"
          if ["show_list"].include?(@lastaction)
            return "vmvdis_center_tb"
          else
            return "vmvdi_center_tb"
          end
        elsif ["my_tasks","my_ui_tasks","all_tasks","all_ui_tasks"].include?(@layout)
          return "tasks_center_tb"
        end
      end
    end
    return "blank_view_tb"
  end

  # check if back to summary button needs to be show
  def display_back_button?
    # don't need to back button if @record is not there or @record doesnt have name or
    # evm_display_name column, i.e MiqProvisionRequest
    if (%w(advanced_settings drift_history event_logs guest_applications groups
           host_services kernel_drivers filesystem_drivers filesystems linux_initprocesses
           patches processes registry_items scan_histories scan_history vmtree
           rsop users vdi_sessions vdi_session_item win32_services).include?(@lastaction) ||
        (@lastaction == "show" && @display != "main")) && @record &&
        ((@layout == "cim_base_storage_extent" && !@record.evm_display_name.nil?) ||
            (@layout != "cim_base_storage_extent" && @record.respond_to?('name') && !@record.name.nil?))
      return true
    else
      return false
    end
  end

  # Do we show or hide the clear_search link in the list view title
  def clear_search_show_or_hide
    @edit && @edit.fetch_path(:adv_search_applied, :text) ? "show" : "hide"
  end

  # Create time zone list for perf chart options screen
  def perf_options_timezones
    if @perf_record && @perf_record.is_a?(MiqCimInstance) && @perf_options[:typ] == "Daily"
      tp_tzs = TimeProfile.rollup_daily_metrics.all_timezones
      ALL_TIMEZONES.dup.delete_if{|tz| !tp_tzs.include?(tz.last)}
    else
      ALL_TIMEZONES
    end
  end

  # Should we allow the user input checkbox be shown for an atom in the expression editor
  QS_VALID_USER_INPUT_OPERATORS = ["=", "!=", ">", ">=", "<", "<=", "INCLUDES", "STARTS WITH", "ENDS WITH", "CONTAINS"]
  QS_VALID_FIELD_TYPES = [:string, :boolean, :integer, :float, :percent, :bytes, :megabytes]
  def qs_show_user_input_checkbox?
    return false unless @edit[:adv_search_open]  # Only allow user input for advanced searches
    return false unless QS_VALID_USER_INPUT_OPERATORS.include?(@edit[@expkey][:exp_key])
    val = (@edit[@expkey][:exp_typ] == "field" &&     # Field atoms with certain field types return true
           QS_VALID_FIELD_TYPES.include?(@edit[@expkey][:val1][:type])) ||
          (@edit[@expkey][:exp_typ] == "tag" &&       # Tag atoms with a tag category chosen return true
           @edit[@expkey][:exp_tag]) ||
          (@edit[@expkey][:exp_typ] == "count" &&     # Count atoms with a count col chosen return true
              @edit[@expkey][:exp_count])
    return val
  end

  # Should we allow the field alias checkbox to be shown for an atom in the expression editor
  def adv_search_show_alias_checkbox?
    return @edit[:adv_search_open]  # Only allow field aliases for advanced searches
  end

  def saved_report_paging?
    # saved report doesn't use miq_report object,
    #need to use a different paging view to page thru a saved report
    return @sb[:pages] && @html &&
        [:reports_tree,:savedreports_tree].include?(x_active_tree) ? true : false
  end

  def pressed2model_action(pressed)
    pressed =~ /^(ems_cluster|vm_vdi|miq_template)_(.*)$/ ? [$1, $2] : pressed.split('_', 2)
  end

  def model_for_ems(record)
    raise "Record is not ExtManagementSystem class" unless record.kind_of?(ExtManagementSystem)
    record.kind_of?(EmsInfra) ? EmsInfra : EmsCloud
  end

  def model_for_vm(record)
    raise "Record is not VmOrTemplate class" unless record.kind_of?(VmOrTemplate)
    if record.kind_of?(VmCloud)
      VmCloud
    elsif record.kind_of?(VmInfra)
      VmInfra
    elsif record.kind_of?(TemplateCloud)
      TemplateCloud
    elsif record.kind_of?(TemplateInfra)
      TemplateInfra
    end
  end

  def controller_for_vm(model)
    case model.to_s
      when "TemplateCloud", "VmCloud"
        "vm_cloud"
      when "TemplateInfra", "VmInfra"
        "vm_infra"
      else
        "vm_or_template"
    end
  end

  def vm_model_from_active_tree(tree)
    case tree
      when :instances_filter_tree
        "VmCloud"
      when :images_filter_tree
        "TemplateCloud"
      when :vms_filter_tree
        "VmInfra"
      when :templates_filter_tree
        "TemplateInfra"
      when :instances_filter_tree
        "VmCloud"
      when :templates_images_filter_tree
        "MiqTemplate"
      when :vms_instances_filter_tree
        "Vm"
    end
  end

  def object_types_for_flash_message(klass, record_ids)
    if klass == VmOrTemplate
      object_ary = klass.where(:id => record_ids).collect {|rec| ui_lookup(:model => model_for_vm(rec).to_s)}
      obj_hash = object_ary.each.with_object(Hash.new(0)) { |obj, h| h[obj] += 1}
      obj_hash.collect { |k, v| v == 1 ? k : k.pluralize }.sort.to_sentence
    else
      object = ui_lookup(:model => klass.to_s)
      record_ids.length == 1 ? object : object.pluralize
    end
  end

  # Same as link_if_condition for cases where the condition is a zero equality
  # test.
  #
  # args (same as link_if_condition) plus:
  #   :count    --- fixnum  - the number to test and present
  #
  def link_if_nonzero(args)
    link_if_condition(args.update(:condition => args[:count] != 0))
  end

  # Function returns a HTML fragment that represents a link to related entity
  # or list of related entities of certain type in case of a condition being
  # met or information about non-existence of such entity if condition is not
  # met.
  #
  # args
  #     :cond         --- bool    - the condition to be met
  #     :table/tables --- string  - name of entity
  #                               - determines singular/plural case
  #     :link_text    --- string  - to override calculated link text
  #     :display      --- string  - FIXME
  #     :[count]      --- fixnum  - number of entities, must be set if :tables
  #                                 is used
  #   args to construct URL
  #     :[controller] --- controller name
  #     :[action]     --- controller action
  #     :record_id    --- id of record
  #
  def link_if_condition(args)
    if args.key?(:tables) # plural case
      entity_name = ui_lookup(:tables => args[:tables])
      link_text   = args.key?(:link_text) ? "#{args[:link_text]} (#{args[:count]})" : "#{entity_name} (#{args[:count]})"
      none        = '(0)'
      title       = "Show all #{entity_name}"
    else                  # singular case
      entity_name = ui_lookup(:table  => args[:table])
      link_text   = args.key?(:link_text) ? args[:link_text] : entity_name
      link_text   = "#{link_text} (#{args[:count]})" if args.key?(:count)
      none        = '(0)'
      title       = "Show #{entity_name}"
    end
    title = args[:title] if args.key?(:title)
    if args[:condition]
      link_params = {
        :action  => args[:action].present? ? args[:action] : 'show',
        :display => args[:display],
        :id      => args[:record_id].to_s
      }
      link_params[:controller] = args[:controller] if args.key?(:controller)

      tag_attrs = { :title => title }
      check_changes = args[:check_changes] || args[:check_changes].nil?
      tag_attrs[:onclick] = 'return miqCheckForChanges()' if check_changes

      link_to_with_icon(link_text, link_params, tag_attrs, args[:image_path])
    else
      content_tag(:p) do
        image_tag('/images/icons/16/link_none.gif') + "#{args.key?(:link_text) ? args[:link_text] : entity_name} #{none}"
      end
    end
  end

  def link_to_with_icon(link_text, link_params, tag_args, image_path=nil)
    tag_args ||= {}
    image_path ||= '/images/icons/16/link_internal.gif'
    default_tag_args = { :onclick => "return miqCheckForChanges()" }
    tag_args = default_tag_args.merge(tag_args)
    link_to(image_tag(image_path), link_params, tag_args) +
      link_to(link_text, link_params, tag_args)
  end

  def center_div_height(toolbar = true, min = 200)
    max = toolbar ? 627 : 757
    height = @winH < max ? min : @winH - (max - min)
    return height
  end

  # Hash to map primary nav ids to the @layout setting for each secondary nav
  NAV_LAYOUT_MAP = {
    :vi  => %w{dashboard report chargeback timeline rss},
    :svc => %w{services catalogs vm_or_template miq_request_vm},
    :clo => %w{ems_cloud availability_zone flavor security_group vm_cloud},
    :inf => %w{ems_infra ems_cluster host vm_infra resource_pool storage repository pxe miq_request_host},
    :vdi => %w{vdi_farm vdi_controller vdi_desktop_pool vdi_desktop vdi_endpoint_device vdi_user vm_vdi},
    :sto => %w{ontap_storage_system ontap_logical_disk ontap_storage_volume ontap_file_share storage_manager},
    :con => %w{miq_policy miq_policy_rsop miq_policy_export miq_policy_logs},
    :aut => %w{miq_ae_class miq_ae_tools miq_ae_customization miq_ae_export miq_ae_logs miq_request_ae},
    :opt => %w{miq_capacity_utilization miq_capacity_planning miq_capacity_bottlenecks},
    :set => %w{configuration my_tasks my_ui_tasks all_tasks all_ui_tasks ops miq_proxy about},
  }

  def primary_nav_class(nav_id)
    NAV_LAYOUT_MAP[nav_id].include?(@layout) ? "active" : "inactive"
  end

  def secondary_nav_class(nav_layout)
    nav_layout == @layout ? "active" : "inactive"
  end

  def render_flash_msg?
    # Don't render flash message in gtl, partial is already being rendered on screen
    return false if request.parameters[:controller] == "miq_request" && @lastaction == "show_list"
    return false if request.parameters[:controller] == "ops" && @lastaction == "product_updates_list"
    return false if request.parameters[:controller] == "service" && @lastaction == "show" && @view
    return true
  end

  def control_selected?
    params[:ppsetting] || params[:searchtag] || params[:entry] ||
      params[:sortby] || params[:sort_choice] || params[:page] || params[:type]
  end

  def perfmenu_click?
    return false unless params[:menu_click]
    perf_menu_click
    true
  end

  def record_no_longer_exists?(what, model = nil)
    return false unless what.nil?
    add_flash(@bang || model.present? ?
      I18n.t("flash.record.no_longer_exists", :model => ui_lookup(:model => model)) :
      I18n.t("flash.error_no_longer_exists"))
    session[:flash_msgs] = @flash_array
    # Error message is displayed in 'show_list' action if such action exists
    # otherwise we assume that the 'explorer' action must exist that will display it.
    redirect_to(:action => respond_to?(:show_list) ? 'show_list' : 'explorer')
  end

  def pdf_page_size_style
    "#{@options[:page_size] || "US-Legal"} #{@options[:page_layout]}"
  end

  # TODO: Remove when IE8 is no longer supported
  # IE8 does not pass referer information via page.redirect_to, here's the ugly workaround.
  def ie8_safe_redirect(page, url)
    if request.headers['HTTP_USER_AGENT'].downcase.include?("msie 8")
      page << "var refererLink = document.createElement('a');"
      page << "refererLink.setAttribute('href', '#{url}');"
      page << "document.body.appendChild(refererLink);"
      page << "refererLink.click();"
    else
      page.redirect_to(url)
    end
  end
end
