module ApplicationHelper
  include_concern 'Dialogs'
  include_concern 'PageLayouts'
  include Sandbox
  include CompressedIds

  def css_background_color
    (@css || {}).fetch_path(:background_color) || 'black'
  end

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

  # Create a collapsed panel based on a condition
  def patternfly_accordion_panel(title, condition, id, &block)
    content_tag(:div, :class => "panel panel-default") do
      out  = content_tag(:div, :class => "panel-heading") do
        content_tag(:h4, :class => "panel-title") do
          link_to(title, "##{id}",
            'data-parent' => '#accordion',
            'data-toggle' => 'collapse',
            :class        => condition ? '' : 'collapsed')
        end
      end
      out << content_tag(:div, :id => id, :class => "panel-collapse collapse #{condition ? 'in' : ''}") do
        content_tag(:div, :class => "panel-body", &block)
      end
    end
  end

  # Create a hidden div area based on a condition (using for hiding nav panes)
  def hidden_div_if(condition, options = {}, &block)
    hidden_tag_if(:div, condition, options, &block)
  end

  # Create a hidden span tag based on a condition (using for hiding nav panes)
  def hidden_span_if(condition, options = {}, &block)
    hidden_tag_if(:span, condition, options, &block)
  end

  def hidden_tag_if(tag, condition, options = {}, &block)
    options[:style] = "display: none" if condition
    if block_given?
      content_tag(tag, options, &block)
    else
      # TODO: Remove this old open-tag-only way in favor of block style
      tag(tag, options, true)
    end
  end

  # Check role based authorization for a UI task
  def role_allows(options={})
    ApplicationHelper.role_allows_intern(options) rescue false
  end

  def role_allows_intern(options = {})
    userid  = User.current_userid
    role_id = User.current_user.miq_user_role.try(:id)
    if options[:feature]
      auth = options[:any] ? User.current_user.role_allows_any?(:identifiers => [options[:feature]]) :
                             User.current_user.role_allows?(:identifier => options[:feature])
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], role id [#{role_id}], feature identifier [#{options[:feature]}]")
    else
      auth = false
      $log.debug("Role Authorization #{auth ? "successful" : "failed"} for: userid [#{userid}], role id [#{role_id}], no main tab or feature passed to role_allows")
    end
    auth
  end
  module_function :role_allows_intern

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
      return url_for_db(controller_for_vm(model_for_vm(record)), action)
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
    elsif %w(ConfiguredSystem ConfigurationProfile).include?(db)
      return url_for(:controller => "provider_foreman", :action => @lastaction, :id => @record, :show => @id)
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
    when "CloudNetwork"     then association = "cloud_networks"
    when "OrchestrationStackOutput" then association = "outputs"
    when "OrchestrationStackParameter" then association = "parameters"
    when "OrchestrationStackResource"  then association = "resources"
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
          elsif %w(ConfigurationProfile).include?(view.db) &&
                request.parameters[:controller] == "provider_foreman"
            return url_for(:action => action, :id => nil) + "/"
          elsif %w(ConfiguredSystem).include?(view.db) && request.parameters[:controller] == "provider_foreman"
            return url_for(:action => action, :id => nil) + "/"
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
      return url_for(:controller=>parent.kind_of?(VmOrTemplate) && !@explorer ? parent.class.base_model.to_s.underscore : request.parameters["controller"],
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
    when "CloudNetwork", "OrchestrationStackOutput", "OrchestrationStackParameter", "OrchestrationStackResource"
      controller = request.parameters[:controller]
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

          if bgi[:buttonSelect] == "chargeback_download_choice" && x_active_tree == :cb_reports_tree &&
            @report && !@report.contains_records?
            props["enabled"] = "false"
            props["title"] = _("No records found for this report")
          end

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
              props = {"id"=>"sep_#{bg_idx}_#{bsi_idx}", "type"=>"separator"}
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
          bgi[:hidden] = %w(download_view vm_download_pdf).include?(bgi[:button]) && button_hide
          eval("title = \"#{bgi[:title]}\"") if !bgi[:title].blank? # Evaluate substitutions in text
          props["title"] = dis_title.is_a?(String) ? dis_title : title

          if bgi[:button] == "chargeback_report_only" && x_active_tree == :cb_reports_tree &&
             @report && !@report.contains_records?
            props["enabled"] = "false"
            props["title"] = _("No records found for this report")
          end

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
    button[:url_parms] = "?id=#{record.id}&button_id=#{button_id}&cls=#{record.class}&pressed=custom_button&desc=#{button_name}"
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
    cbses.sort_by { |cbs| cbs[:set_data][:group_index] }.collect do |cbs|
      group = Hash.new
      group[:id]           = cbs.id
      group[:text]         = cbs.name.split("|").first
      group[:description]  = cbs.description
      group[:image]        = cbs.set_data[:button_image]
      group[:text_display] = cbs.set_data.has_key?(:display) ? cbs.set_data[:display] : true

      available = CustomButton.available_for_user(session[:userid], cbs.name) # get all uri records for this user for specified uri set
      available = available.select { |b| cbs.members.include?(b) }            # making sure available_for_user uri is one of the members
      group[:buttons] = available.collect { |cb| create_raw_custom_button_hash(cb, record) }.uniq
      if cbs[:set_data][:button_order] # Show custom buttons in the order they were saved
        ordered_buttons = []
        cbs[:set_data][:button_order].each do |bidx|
          group[:buttons].each do |b|
            if bidx == b[:id] and !ordered_buttons.include?(b)
              ordered_buttons.push(b)
              break
            end
          end
        end
        group[:buttons] = ordered_buttons
      end
      group
    end
  end

  def get_image(img, b_name)
    # to change summary screen button to green image
    return "summary-green" if b_name == "show_summary" && %w(miq_schedule miq_task scan_profile).include?(@layout)
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
              return @record.class != MiqServer
            when "role_start", "role_suspend", "zone_role_start", "zone_role_suspend"
              return !(@record.class == AssignedServerRole && @record.miq_server.started?)
            when "demote_server", "promote_server", "zone_demote_server", "zone_promote_server"
              return !(@record.class == AssignedServerRole && @record.master_supported?)
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
        id != "customization_template_new"
      elsif nodes.last == "system" || (@record && @record.system)
        # allow only copy button for system customization templates
        id != "customization_template_copy"
      else
        false
      end
    else
      !role_allows(:feature => id)
    end
  end

  def build_toolbar_hide_button_report(id)
    if %w(miq_report_copy miq_report_delete miq_report_edit
          miq_report_new miq_report_run miq_report_schedule_add).include?(id) ||
        x_active_tree == :schedules_tree
      return true unless role_allows(:feature => id)
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
          return @sb[:active_tab] != "saved_reports"
        when "miq_report_edit", "miq_report_delete"
          return @sb[:active_tab] == "report_info" && @record.rpt_type == "Custom" ?
                 false : true
        when "miq_report_copy", "miq_report_new", "miq_report_run", "miq_report_only", "miq_report_schedule_add"
          return @sb[:active_tab] == "saved_reports"
        when "view_graph", "view_hybrid", "view_tabular"
          return @ght_type && @report && @report.graph &&
                 (@zgraph || (@ght_type == "tabular" && @html)) ? false : true
        end
      when :savedreports_tree
        case id
          when "reload"
            return x_node != "root"
          when "view_graph","view_hybrid","view_tabular"
            return @ght_type && @report && @report.graph &&
                (@zgraph || (@ght_type == "tabular" && @html)) ? false : true
        end
      else
        return false
    end
  end

  def build_toolbar_hide_button_service(id)
    case id
    when "service_reconfigure"
      ra = @record.service_template.resource_actions.find_by_action('Reconfigure') if @record.service_template
      return true if ra.nil? || ra.fqname.blank?
    end
    false
  end

  # Determine if a button should be hidden
  def build_toolbar_hide_button(id)
    return true if id == "blank_button" # Always hide the blank button placeholder

    # Hide configuration buttons for specific Container* entities
    return true if %w(container_node_edit container_node_delete container_node_new).include?(id) &&
                   (@record.kind_of?(ContainerNode) || @record.nil?)

    return true if %w(container_service_edit container_service_delete container_service_new).include?(id) &&
                   (@record.kind_of?(ContainerService) || @record.nil?)

    return true if %w(container_group_edit container_group_delete container_group_new).include?(id) &&
                   (@record.kind_of?(ContainerGroup) || @record.nil?)

    return true if %w(container_edit container_delete container_new).include?(id) &&
                   (@record.kind_of?(Container) || @record.nil?)

    return true if %w(container_replicator_edit container_replicator_delete container_replicator_new).include?(id) &&
                   (@record.kind_of?(ContainerReplicator) || @record.nil?)

    # hide timelines button for Amazon provider and instances
    # TODO: extend .is_available? support via refactoring task to cover this scenario
    return true if ['ems_cloud_timeline', 'instance_timeline'].include?(id) && (@record.kind_of?(EmsAmazon) || @record.kind_of?(VmAmazon))

    # hide edit button for MiqRequest instances of type ServiceReconfigureRequest/ServiceTemplateProvisionRequest
    # TODO: extend .is_available? support via refactoring task to cover this scenario
    return true if id == 'miq_request_edit' &&
                   %w(ServiceReconfigureRequest ServiceTemplateProvisionRequest).include?(@miq_request.try(:type))

    # only hide gtl button if they are not in @temp
    return @temp[:gtl_buttons].include?(id) ? false : true if @temp &&
                                                @temp[:gtl_buttons] && ["view_grid","view_tile","view_list"].include?(id)

    #don't hide view buttons in toolbar
    return false if %( view_grid view_tile view_list refresh_log fetch_log common_drift
      download_text download_csv download_pdf download_view vm_download_pdf
      tree_large tree_small).include?(id) && !%w(miq_policy_rsop ops).include?(@layout)

    # dont hide back to summary button button when not in explorer
    return false if id == "show_summary" && !@explorer

    #need to hide add buttons when on sub-list view screen of a CI.
    return true if (id.ends_with?("_new") || id.ends_with?("_discover")) &&
                            @lastaction == "show" && @display != "main"

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
    unless %w(miq_policy catalogs).include?(@layout)
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
    when "vm_console"
      type = get_vmdb_config.fetch_path(:server, :remote_console_type)
      return type != 'MKS' || !@record.console_supported?(type)
    when "vm_vnc_console"
      return !@record.console_supported?('vnc')
    when "vm_vmrc_console"
      type = get_vmdb_config.fetch_path(:server, :remote_console_type)
      return type != 'VMRC' || !@record.console_supported?(type)
    # Check buttons behind SMIS setting
    when "ontap_storage_system_statistics", "ontap_logical_disk_statistics", "ontap_storage_volume_statistics",
        "ontap_file_share_statistics"
      return true unless get_vmdb_config[:product][:smis]
    when 'vm_publish'
      return true if @is_redhat
    end

    # Scale is only supported by OpenStack Infrastructure Provider
    return true if id == "ems_infra_scale" &&
                   (@record.class.name != "EmsOpenstackInfra" ||
                    !role_allows(:feature => "ems_infra_scale") ||
                   (@record.class.name == "EmsOpenstackInfra" && @record.orchestration_stacks.count == 0))

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
      return false if MIQ_AE_COPY_ACTIONS.include?(id) && MiqAeDomain.any_unlocked?
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
    when "MiqProvisionRequest", "MiqHostProvisionRequest", "VmReconfigureRequest",
        "VmMigrateRequest", "AutomationRequest",
        "ServiceReconfigureRequest", "ServiceTemplateProvisionRequest", "MiqProvisionConfiguredSystemRequest"

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
        resource_types_for_miq_request_copy = %w(MiqProvisionRequest
                                                 MiqHostProvisionRequest
                                                 MiqProvisionConfiguredSystemRequest)
        return true if !resource_types_for_miq_request_copy.include?(@record.resource_type) ||
                       ((requester.name != @record.requester_name ||
                         !@record.request_pending_approval?) &&
                        @showtype == "miq_provisions")
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
    when "Service"
      return build_toolbar_hide_button_service(id)
    when "Vm"
      case id
      when "vm_clone"
        return true unless @record.cloneable?
      when "vm_publish"
        return true if %w(VmMicrosoft VmRedhat).include?(@record.type)
      when "vm_collect_running_processes"
        return true if (@record.retired || @record.current_state == "never") && !@record.is_available?(:collect_running_processes)
      when "vm_guest_startup", "vm_start", "instance_start", "instance_resume"
        return true if !@record.is_available?(:start)
      when "vm_guest_standby"
        return true if !@record.is_available?(:standby_guest)
      when "vm_guest_shutdown", "instance_guest_shutdown"
        return true if !@record.is_available?(:shutdown_guest)
      when "vm_guest_restart", "instance_guest_restart"
        return true if !@record.is_available?(:reboot_guest)
      when "vm_migrate", "vm_reconfigure"
        return true if @record.vendor.downcase == "redhat"
      when "vm_stop", "instance_stop"
        return true if !@record.is_available?(:stop)
      when "vm_reset", "instance_reset"
        return true if !@record.is_available?(:reset)
      when "vm_suspend", "instance_suspend"
        return true if !@record.is_available?(:suspend)
      when "instance_pause"
        return true if !@record.is_available?(:pause)
      when "vm_policy_sim", "vm_protect"
        return true if @record.host && @record.host.vmm_product.to_s.downcase == "workstation"
      when "vm_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "vm_scan", "instance_scan"
        return true if !@record.has_proxy?
      when "perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "MiqTemplate"
      case id
      when "miq_template_clone"
        return true unless @record.cloneable?
      when "miq_template_policy_sim", "miq_template_protect"
        return true if @record.host && @record.host.vmm_product.downcase == "workstation"
      when "miq_template_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "miq_template_scan"
        return true if !@record.has_proxy?
      when "miq_template_refresh", "miq_template_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "OrchestrationTemplate", "OrchestrationTemplateCfn", "OrchestrationTemplateHot"
      return true unless role_allows(:feature => id)
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
    return true if id.starts_with?("view_") && id.ends_with?("textual")  # Summary view buttons
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
    when "ContainerNodeKubernetes"
      case id
      when "container_node_timeline"
        return "No Timeline data has been collected for this Node" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "ContainerGroupKubernetes"
      case id
      when "container_group_timeline"
        return "No Timeline data has been collected for this ContainerGroup" unless @record.has_events? || @record.has_events?(:policy_events)
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
        return "Log collection requires the Log Depot settings to be configured" unless @record.log_depot
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
    when "OrchestrationTemplateCfn", "OrchestrationTemplateHot"
      case id
      when "orchestration_template_remove"
        return "Read-only Orchestration Template cannot be deleted" if @record.stacks.length > 0
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
      when "instance_perf", "vm_perf"
        return "No Capacity & Utilization data has been collected for this VM" unless @record.has_perf_data?
      when "instance_check_compliance", "vm_check_compliance"
        model = model_for_vm(@record).to_s
        return "No Compliance Policies assigned to this #{model == "VmInfra" ? "VM" : ui_lookup(:model => model)}" unless @record.has_compliance_policies?
      when "vm_collect_running_processes"
        return @record.is_available_now_error_message(:collect_running_processes) if @record.is_available_now_error_message(:collect_running_processes)
      when "vm_console", "vm_vmrc_console"
        if !is_browser?(%w(explorer firefox mozilla chrome)) ||
          !is_browser_os?(%w(windows linux))
          return "The web-based console is only available on IE, Firefox or Chrome (Windows/Linux)"
        end

        if id.in?(["vm_vmrc_console"])
          begin
            @record.validate_remote_console_vmrc_support
          rescue MiqException::RemoteConsoleNotSupportedError => err
            return "VM VMRC Console error: #{err}"
          end
        end

        return "The web-based console is not available because the VM is not powered on" if @record.current_state != "on"
      when "vm_vnc_console"
        return "The web-based VNC console is not available because the VM is not powered on" if @record.current_state != "on"
      when "vm_guest_startup", "vm_start"
        return @record.is_available_now_error_message(:start) if @record.is_available_now_error_message(:start)
      when "vm_guest_standby"
        return @record.is_available_now_error_message(:standby_guest) if @record.is_available_now_error_message(:standby_guest)
      when "vm_guest_shutdown"
        return @record.is_available_now_error_message(:shutdown_guest) if @record.is_available_now_error_message(:shutdown_guest)
      when "vm_guest_restart"
        return @record.is_available_now_error_message(:reboot_guest) if @record.is_available_now_error_message(:reboot_guest)
      when "vm_stop"
        return @record.is_available_now_error_message(:stop) if @record.is_available_now_error_message(:stop)
      when "vm_reset"
        return @record.is_available_now_error_message(:reset) if @record.is_available_now_error_message(:reset)
      when "vm_suspend"
        return @record.is_available_now_error_message(:suspend) if @record.is_available_now_error_message(:suspend)
      when "instance_retire", "instance_retire_now",
              "vm_retire", "vm_retire_now"
        return "#{@record.kind_of?(VmCloud) ? "Instance" : "VM"} is already retired" if @record.retired == true
      when "vm_scan", "instance_scan"
        return @record.active_proxy_error_message if !@record.has_active_proxy?
      when "vm_timeline"
        return "No Timeline data has been collected for this VM" unless @record.has_events? || @record.has_events?(:policy_events)
      when "vm_snapshot_add"
        if @record.number_of(:snapshots) <= 0
          return @record.is_available_now_error_message(:create_snapshot) unless @record.is_available?(:create_snapshot)
        else
          unless @record.is_available?(:create_snapshot)
            return @record.is_available_now_error_message(:create_snapshot)
          else
            return "Select the Active snapshot to create a new snapshot for this VM" unless @active
          end
        end
      when "vm_snapshot_delete"
        return @record.is_available_now_error_message(:remove_snapshot) unless @record.is_available?(:remove_snapshot)
      when "vm_snapshot_delete_all"
        return @record.is_available_now_error_message(:remove_all_snapshots) unless @record.is_available?(:remove_all_snapshots)
      when "vm_snapshot_revert"
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
    when "Zone"
      case id
      when "collect_logs", "collect_current_logs"
        return "Cannot collect current logs unless there are started #{ui_lookup(:tables=>"miq_servers")} in the Zone" if @record.miq_servers.collect { |s| s.status == "started" ? true : nil }.compact.length == 0
        return "This Zone and one or more active #{ui_lookup(:tables=>"miq_servers")} in this Zone do not have Log Depot settings configured, collection not allowed" if @record.miq_servers.select(&:log_depot).blank?
        return "Log collection is already in progress for one or more #{ui_lookup(:tables=>"miq_servers")} in this Zone" if @record.log_collection_active_recently?
      when "zone_delete"
        if @selected_zone.name.downcase == "default"
          return "'Default' zone cannot be deleted"
        elsif @selected_zone.ext_management_systems.count > 0 ||
            @selected_zone.storage_managers.count > 0 ||
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
    return check_for_utilization_download_buttons if %w(miq_capacity_download_csv
                                                        miq_capacity_download_pdf
                                                        miq_capacity_download_text).include?(id)
    false
  end

  def check_for_utilization_download_buttons
    return false if x_active_tree.nil? &&
                    @sb.fetch_path(:planning, :rpt) &&
                    !@sb[:planning][:rpt].table.data.empty?
    return false if @sb.fetch_path(:util, :trend_rpt) &&
                    @sb.fetch_path(:util, :summary)
    "No records found for this report"
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
    return true if id.starts_with?("view_") && id.ends_with?("textual")  # Summary view buttons
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

    collect_log_buttons = %w(support_vmdb_choice__collect_logs
                             support_vmdb_choice__collect_current_logs
                             support_vmdb_choice__zone_collect_logs
                             support_vmdb_choice__zone_collect_current_logs
    )

    if tb_buttons[button][:name].in?(collect_log_buttons) && @record.try(:log_depot).try(:requires_support_case?)
      tb_buttons[button][:prompt] = true
    end
    eval("parms = \"#{item[:url_parms]}\"") if item[:url_parms]
    tb_buttons[button][:url_parms] = update_url_parms(parms) if item[:url_parms]
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
    # TODO: leave I18n until we have productization capability in gettext
    title = I18n.t('product.name')
    if layout.blank?  # no layout, leave title alone
    elsif ["configuration", "dashboard", "chargeback", "about"].include?(layout)
      title += ": #{layout.titleize}"
    elsif @layout == "ems_cluster"
      title += ": #{title_for_clusters}"
    elsif @layout == "host"
      title += ": #{title_for_hosts}"
    # Specific titles for certain layouts
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
    elsif layout == "my_ui_tasks"
      title += ": My UI Tasks"
    elsif layout == "rss"
      title += ": RSS"
    elsif layout == "storage_manager"
      title += ": Storage - Storage Managers"
    elsif layout == "ops"
      title += ": Configuration"
    elsif layout == "provider_foreman"
      title += ": #{ui_lookup(:ui_title => "foreman")} #{ui_lookup(:model => "ExtManagementSystem")}"
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
    elsif layout.starts_with?("cim_") ||
          layout.starts_with?("snia_")
      title += ": Storage - #{ui_lookup(:tables=>layout)}"
    elsif layout == "login"
      title += ": Login"
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
        js_array << javascript_hide("weekly_span")
        js_array << javascript_hide("daily_span")
        js_array << javascript_hide("hourly_span")
        js_array << javascript_show("monthly_span")
      when "Weekly"
        js_array << javascript_hide("daily_span")
        js_array << javascript_hide("hourly_span")
        js_array << javascript_hide("monthly_span")
        js_array << javascript_show("weekly_span")
      when "Daily"
        js_array << javascript_hide("hourly_span")
        js_array << javascript_hide("monthly_span")
        js_array << javascript_hide("weekly_span")
        js_array << javascript_show("daily_span")
      when "Hourly"
        js_array << javascript_hide("daily_span")
        js_array << javascript_hide("monthly_span")
        js_array << javascript_hide("weekly_span")
        js_array << javascript_show("hourly_span")
      else
        js_array << javascript_hide("daily_span")
        js_array << javascript_hide("hourly_span")
        js_array << javascript_hide("monthly_span")
        js_array << javascript_hide("weekly_span")
      end
    end
    js_array
  end

  # Show/hide the Save and Reset buttons based on whether changes have been made
  def javascript_for_miq_button_visibility(display, prefix = nil)
    if prefix
      "miqButtons('#{display ? 'show' : 'hide'}', '#{prefix}');".html_safe
    else
      "miqButtons('#{display ? 'show' : 'hide'}');".html_safe
    end
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
      js_array << "$('##{tree_name_escaped}box').dynatree('getTree').getNodeByKey('#{params[:id].split('___').last}').data.addClass = '#{css_class}';"
    end
    # need to redraw the tree to change node colors
    js_array << "tree = $('##{tree_name_escaped}box').dynatree('getTree');"
    js_array << "tree.redraw();"
    js_array.join("\n")
  end

  # Reload toolbars using new buttons object and xml
  def javascript_for_toolbar_reload(tb, buttons, xml)
    %Q{
      if (miq_toolbars.#{tb} && miq_toolbars.#{tb}.obj)
        miq_toolbars.#{tb}.obj.unload();

      if (document.getElementById('#{tb}') == null) {
        var tb_div = $('<div id="#{tb}" />');
        parent_div_id = '#{tb}'.split('_')[0] + '_buttons_div';
        $("#" + parent_div_id).append(tb_div);
      }

      window.#{tb} = new dhtmlXToolbarObject('#{tb}', 'miq_blue');
      miq_toolbars['#{tb}'] = {
        obj: window.#{tb},
        buttons: #{buttons},
        xml: "#{xml}"
      };

      miqInitToolbar(miq_toolbars['#{tb}']);
    }
  end

  def javascript_for_ae_node_selection(id, prev_id, select)
    "cfmeSetAETreeNodeSelectionClass('#{id}', '#{prev_id}', '#{select ? true : false}');".html_safe
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
    "$('##{element_id}').val('#{value}');"
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
      t                          = schedule.run_at[:start_time].utc.in_time_zone(@edit[:tz])
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
        %w(auth_error change_tab show).include?(controller.action_name) ||
        %w(about chargeback exception miq_ae_automate_button miq_ae_class miq_ae_export
           miq_ae_tools miq_capacity_bottlenecks miq_capacity_planning miq_capacity_utilization
           miq_capacity_waste miq_policy miq_policy_export miq_policy_rsop ops pxe report rss
           server_build).include?(@layout) ||
        (@layout == "configuration" && @tabform != "ui_4")) && !controller.action_name.end_with?("tagging_edit")
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
    return celltext
  end

  def check_if_button_is_implemented
    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @ems = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
  end

  # Truncate text to fit below a quad icon
  TRUNC_AT = 13
  TRUNC_TO = 10
  def truncate_for_quad(value)
    return value if value.to_s.length < TRUNC_AT
    case @settings.fetch_path(:display, :quad_truncate)
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
      elsif @layout == "provider_foreman"
        if x_active_tree == :foreman_providers_tree || :cs_filter_tree
          return center_toolbar_filename_foreman_providers
        end
      else
        if x_active_tree == :ae_tree
          return center_toolbar_filename_automate
        elsif x_active_tree == :containers_tree
          return center_toolbar_filename_containers
        elsif [:sandt_tree, :svccat_tree, :stcat_tree, :svcs_tree, :ot_tree].include?(x_active_tree)
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
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplate"
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
    elsif x_active_tree == :stcat_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplateCatalog"
        return "servicetemplatecatalog_center_tb"
      else
        return "servicetemplatecatalogs_center_tb"
      end
    elsif x_active_tree == :svcs_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "Service"
        return "service_center_tb"
      else
        return "services_center_tb"
      end
    elsif x_active_tree == :ot_tree
      if %w(root xx-otcfn xx-othot).include?(x_node)
        return "orchestration_templates_center_tb"
      else
        return "orchestration_template_center_tb"
      end
    end
  end

  def center_toolbar_filename_containers
    TreeBuilder.get_model_for_prefix(@nodetype) == "Container" ? "containers_center_tb" : "container_center_tb"
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
      elsif x_node.split('-').last == "sis"
        return "scan_profiles_center_tb"
      elsif x_node.split('-').first == "sis"
        return "scan_profile_center_tb"
      elsif x_node.split('-').last == "z"
        return "zones_center_tb"
      elsif x_node.split('-').first == "z"
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
          "miq_report_schedules_center_tb" : "miq_report_schedule_center_tb"
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
        if %w(availability_zone cloud_tenant container_group container_node container_service ems_cloud ems_cluster
              ems_container container_project container_route container_replicator ems_infra flavor host
              ontap_file_share ontap_logical_disk
              ontap_storage_system orchestration_stack repository resource_pool storage storage_manager
              timeline usage security_group).include?(@layout)
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
        elsif ["miq_request_configured_system", "miq_request_host", "miq_request_vm"].include?(@layout)
          if ["show_list"].include?(@lastaction)
            return "miq_requests_center_tb"
          else
            return "miq_request_center_tb"
          end
        elsif ["my_tasks","my_ui_tasks","all_tasks","all_ui_tasks"].include?(@layout)
          return "tasks_center_tb"
        end
      end
    end
    return "blank_view_tb"
  end

  def center_toolbar_filename_foreman_providers
    nodes = x_node.split('-')
    if x_active_tree == :foreman_providers_tree
      foreman_providers_tree_center_tb(nodes)
    elsif x_active_tree == :cs_filter_tree
      cs_filter_tree_center_tb(nodes)
    end
  end

  def foreman_providers_tree_center_tb(nodes)
    case nodes.first
    when "root" then  "provider_foreman_center_tb"
    when "e"    then  "configuration_profile_foreman_center_tb"
    when "cp"   then  configuration_profile_center_tb
    else unassigned_configuration_profile_node(nodes)
    end
  end

  def cs_filter_tree_center_tb(nodes)
    case nodes.first
    when "root", "ms" then  "configured_system_foreman_center_tb"
    end
  end

  def configuration_profile_center_tb
    if @sb[:active_tab] == "configured_systems"
      "configured_systems_foreman_center_tb"
    else
      "blank_view_tb"
    end
  end

  def unassigned_configuration_profile_node(nodes)
    configuration_profile_center_tb if nodes[2] == "unassigned"
  end

  # check if back to summary button needs to be show
  def display_back_button?
    # don't need to back button if @record is not there or @record doesnt have name or
    # evm_display_name column, i.e MiqProvisionRequest
    if (@lastaction != "show" || (@lastaction == "show" && @display != "main")) &&
       @record &&
       ((@layout == "cim_base_storage_extent" && !@record.evm_display_name.nil?) ||
         (@layout != "cim_base_storage_extent" && @record.respond_to?('name') && !@record.name.nil?))
      return true
    else
      return false
    end
  end

  def display_adv_search?
    %w(availability_zone container_group container_node container_service
       container_route container_project container_replicator
       ems_container vm miq_template offline retired templates
       host service repository storage ems_cloud ems_cluster flavor
       resource_pool ems_infra ontap_storage_system ontap_storage_volume
       ontap_file_share snia_local_file_system ontap_logical_disk
       orchestration_stack cim_base_storage_extent storage_manager
       security_group).include?(@layout)
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
    # need to use a different paging view to page thru a saved report
    @sb[:pages] && @html && [:reports_tree, :savedreports_tree, :cb_reports_tree].include?(x_active_tree)
  end

  def pressed2model_action(pressed)
    pressed =~ /^(ems_cluster|miq_template)_(.*)$/ ? [$1, $2] : pressed.split('_', 2)
  end

  def model_for_ems(record)
    raise "Record is not ExtManagementSystem class" unless record.kind_of?(ExtManagementSystem)
    if record.kind_of?(EmsCloud)
      EmsCloud
    elsif record.kind_of?(EmsContainer)
      EmsContainer
    else
      EmsInfra
    end
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

  # Same as li_link_if_condition for cases where the condition is a zero equality
  # test.
  #
  # args (same as link_if_condition) plus:
  #   :count    --- fixnum  - the number to test and present
  #
  def li_link_if_nonzero(args)
    li_link_if_condition(args.update(:condition => args[:count] != 0))
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
  def li_link_if_condition(args)
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

      tag_attrs = {:title => title}
      check_changes = args[:check_changes] || args[:check_changes].nil?
      tag_attrs[:onclick] = 'return miqCheckForChanges()' if check_changes
      content_tag(:li) do
        link_to(link_text, link_params, tag_attrs)
      end
    else
      content_tag(:li, :class => "disabled") do
        content_tag(:a, :href => "#") do
          "#{args.key?(:link_text) ? args[:link_text] : entity_name} #{none}"
        end
      end
    end
  end

  # Function returns a HTML fragment that represents an image with certain
  # options or an image with link and different options in case of a condition
  # has a true or a false value.
  #
  # args
  #     :cond         --- bool    - the condition to be met
  #     :image        --- string  - the URL of the image
  #     :opts_true    --- hash    - HTML options for image_tag() if cond == true
  #     :opts_false   --- hash    - HTML options for image_tag() if cond == false
  #     :link         --- hash    - options for link_to()
  #     :opts_link    --- hash    - HTML options for link_to()
  #
  def link_image_if(args)
    if args[:cond]
      image_tag(args[:image], args[:opts_true])
    else
      link_to(image_tag(args[:image], args[:opts_false]), args[:link], args[:opts_link])
    end
  end

  def link_to_with_icon(link_text, link_params, tag_args, image_path=nil)
    tag_args ||= {}
    default_tag_args = { :onclick => "return miqCheckForChanges()" }
    tag_args = default_tag_args.merge(tag_args)
      link_to(link_text, link_params, tag_args)
  end

  def center_div_height(toolbar = true, min = 200)
    max = toolbar ? 627 : 757
    height = @winH < max ? min : @winH - (max - min)
    return height
  end

  def primary_nav_class(nav_id)
    test_layout = @layout
    # FIXME: exception behavior to remove
    test_layout = 'my_tasks' if %w(my_tasks my_ui_tasks all_tasks all_ui_tasks).include?(@layout)

    Menu::Manager.item_in_section?(test_layout, nav_id) ? "active" : "dropdown"
  end

  def primary_nav_class2(nav_id)
    test_layout = @layout
    # FIXME: exception behavior to remove
    test_layout = 'my_tasks' if %w(my_tasks my_ui_tasks all_tasks all_ui_tasks).include?(@layout)

    return "dropdown-menu" if big_iframe

    Menu::Manager.item_in_section?(test_layout, nav_id) ? "nav navbar-nav navbar-persistent" : "dropdown-menu"
  end

  def secondary_nav_class(nav_layout)
    if nav_layout == 'my_tasks' # FIXME: exceptional behavior to remove
      nav_layout = %w(my_tasks my_ui_tasks all_tasks all_ui_tasks).include?(@layout) ? @layout : "my_tasks"
    end
    nav_layout == @layout ? "active" : ""
  end

  def render_flash_msg?
    # Don't render flash message in gtl, partial is already being rendered on screen
    return false if request.parameters[:controller] == "miq_request" && @lastaction == "show_list"
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
      _("%s no longer exists") %  ui_lookup(:model => model) :
      _("Error: Record no longer exists in the database"))
    session[:flash_msgs] = @flash_array
    # Error message is displayed in 'show_list' action if such action exists
    # otherwise we assume that the 'explorer' action must exist that will display it.
    redirect_to(:action => respond_to?(:show_list) ? 'show_list' : 'explorer')
  end

  def pdf_page_size_style
    "#{@options[:page_size] || "US-Legal"} #{@options[:page_layout]}"
  end

  GTL_VIEW_LAYOUTS = %w(action availability_zone cim_base_storage_extent cloud_tenant condition container_group
                        container_route container_project container_replicator
                        container_node container_service ems_cloud ems_cluster ems_container ems_infra event
                        flavor host miq_schedule miq_template offline ontap_file_share
                        ontap_logical_disk ontap_storage_system ontap_storage_volume orchestration_stack
                        policy policy_group policy_profile repository resource_pool retired scan_profile
                        service snia_local_file_system storage storage_manager templates)

  def render_gtl_view_tb?
    GTL_VIEW_LAYOUTS.include?(@layout) && @gtl_type && !@tagitems &&
      !@ownershipitems && !@retireitems && !@politems && !@in_a_form &&
      %w(show show_list).include?(params[:action])
  end

  def update_url_parms(url_parm)
    return url_parm if /=/.match(url_parm).nil?

    keep_parms = %w(bc escape menu_click sb_controller)
    query_string = Rack::Utils.parse_query URI("?#{request.query_string}").query
    query_string.delete_if { | k, _v | !keep_parms.include? k }

    url_parm_hash = preprocess_url_param(url_parm)
    query_string.merge!(url_parm_hash)
    URI.decode("?#{query_string.to_query}")
  end

  def preprocess_url_param(url_parm)
    parse_questionmark = /^\?/.match(url_parm)
    parse_ampersand = /^&/.match(url_parm)
    url_parm = parse_questionmark.post_match if parse_questionmark.present?
    url_parm = parse_ampersand.post_match if parse_ampersand.present?
    encoded_url = URI.encode(url_parm)
    Rack::Utils.parse_query URI("?#{encoded_url}").query
  end

  def update_paging_url_parms(action_url, parameter_to_update = {})
    url = update_query_string_params(parameter_to_update)
    action, an_id = action_url.split("/", 2)
    url[:action] = action
    url[:id] = an_id unless an_id.nil?
    url_for(url)
  end

  def update_query_string_params(update_this_param)
    exclude_params = %w(button flash_msg page pressed sortby sort_choice type)
    query_string = Rack::Utils.parse_query URI("?#{request.query_string}").query
    updated_query_string = query_string.symbolize_keys
    updated_query_string.delete_if { | k, _v | exclude_params.include? k.to_s }
    updated_query_string.merge!(update_this_param)
  end

  def placeholder_if_present(password)
    password.present? ? "\u25cf" * 8 : ''
  end

  def render_listnav_filename
    if @lastaction == "show_list" && !session[:menu_click] &&
       %w(container_node container_service ems_container container_group ems_cloud ems_cluster
          container_route container_project container_replicator
          ems_infra host miq_template offline orchestration_stack repository
          resource_pool retired service storage templates vm).include?(@layout) && !@in_a_form
      "show_list"
    elsif @compare
      "compare_sections"
    elsif %w(offline retired templates vm vm_cloud vm_or_template).include?(@layout)
      "vm"
    elsif %w(action availability_zone cim_base_storage_extent cloud_tenant condition container_group
             container_route container_project container_replicator
             container_node container_service ems_cloud ems_container ems_cluster ems_infra flavor
             host miq_schedule miq_template policy ontap_file_share ontap_logical_disk
             ontap_storage_system ontap_storage_volume orchestration_stack repository resource_pool
             scan_profile security_group service snia_local_file_system storage
             storage_manager timeline).include?(@layout)
      @layout
    else
      nil
    end
  end

  def show_adv_search?
    show_search = %w(availability_zone cim_base_storage_extent container_group container_node container_service
                     container_route container_project container_replicator
                     ems_cloud ems_cluster ems_container ems_infra flavor host miq_template offline
                     ontap_file_share ontap_logical_disk ontap_storage_system ontap_storage_volume
                     orchestration_stack repository resource_pool retired security_group service
                     snia_local_file_system storage storage_manager templates vm)
    (@lastaction == "show_list" && !session[:menu_click] && show_search.include?(@layout) && !@in_a_form) ||
      (@explorer &&
       x_tree &&
       [:containers, :filter, :images, :instances, :providers, :vandt].include?(x_tree[:type]) &&
       !@record)
  end

  def need_prov_dialogs?(type)
    !type.starts_with?("generic")
  end

  def db_for_quadicon
    case @layout
    when "ems_infra"
      :ems
    when "ems_cloud"
      :ems_cloud
    else
      :ems_container
    end
  end

  def x_gtl_view_tb_render?
    no_gtl_view_buttons = %w(chargeback miq_ae_class miq_ae_customization miq_ae_tools miq_capacity_planning
                             miq_capacity_utilization miq_policy miq_policy_rsop report ops provider_foreman pxe)
    @record.nil? && @explorer && !no_gtl_view_buttons.include?(@layout)
  end

  def explorer_controller?
    %w(vm_cloud vm_infra vm_or_template).include?(controller_name)
  end

  def vm_quad_link_attributes(record)
    attributes = vm_cloud_attributes(record) if record.kind_of?(VmCloud)
    attributes ||= vm_infra_attributes(record) if record.kind_of?(VmInfra)
    attributes
  end

  def vm_cloud_attributes(record)
    attributes = vm_cloud_explorer_accords_attributes(record)
    attributes ||= service_workload_attributes(record)
    attributes
  end

  def vm_cloud_explorer_accords_attributes(record)
    if role_allows(:feature => "instances_accord") || role_allows(:feature => "instances_filter_accord")
      attributes = {}
      attributes[:link] = true
      attributes[:controller] = "vm_cloud"
      attributes[:action] = "show"
      attributes[:id] = record.id
    end
    attributes
  end

  def vm_infra_attributes(record)
    attributes = vm_infra_explorer_accords_attributes(record)
    attributes ||= service_workload_attributes(record)
    attributes
  end

  def vm_infra_explorer_accords_attributes(record)
    if role_allows(:feature => "vandt_accord") || role_allows(:feature => "vms_filter_accord")
      attributes = {}
      attributes[:link] = true
      attributes[:controller] = "vm_infra"
      attributes[:action] = "show"
      attributes[:id] = record.id
    end
    attributes
  end

  def service_workload_attributes(record)
    attributes = {}
    if role_allows(:feature => "vms_instances_filter_accord")
      attributes[:link] = true
      attributes[:controller] = "vm_or_template"
      attributes[:action] = "explorer"
      attributes[:id] = "v-#{record.id}"
    end
    attributes
  end

  def title_for_hosts
    title_for_host(true)
  end

  def title_for_host(plural = false)
    key = case Host.node_types
          when :non_openstack
            "host_infra"
          when :openstack
            "host_openstack"
          else
            "host"
          end
    ui_lookup(:host_types => plural ? key.pluralize : key)
  end

  def title_for_clusters
    title_for_cluster(true)
  end

  def title_for_cluster(plural = false)
    key = case EmsCluster.node_types
          when :non_openstack
            "cluster_infra"
          when :openstack
            "cluster_openstack"
          else
            "cluster"
          end
    ui_lookup(:ems_cluster_types => plural ? key.pluralize : key)
  end

  def title_for_host_record(record)
    record.openstack_host? ? ui_lookup(:host_types => 'host_openstack') : ui_lookup(:host_types => 'host_infra')
  end

  def title_for_cluster_record(record)
    record.openstack_cluster? ?
      ui_lookup(:ems_cluster_types => 'cluster_openstack') :
      ui_lookup(:ems_cluster_types => 'cluster_infra')
  end

  def start_page_allowed?(start_page)
    storage_start_pages = %w(cim_storage_extent_show_list
                             ontap_file_share_show_list
                             ontap_logical_disk_show_list
                             ontap_storage_system_show_list
                             ontap_storage_volume_show_list
                             storage_manager_show_list)
    return false if storage_start_pages.include?(start_page) && !get_vmdb_config[:product][:storage]
    containers_start_pages = %w(ems_container_show_list
                                container_node_show_list
                                container_group_show_list
                                container_service_show_list
                                container_view)
    return false if containers_start_pages.include?(start_page) && !get_vmdb_config[:product][:containers]
    role_allows(:feature => start_page, :any => true)
  end

  def allowed_filter_db?(db)
    return false if db.start_with?('Container') && !get_vmdb_config[:product][:containers]
    true
  end

  def patternfly_tab_header(id, active, &block)
    content_tag(:li, :class => active == id ? 'active' : '') do
      content_tag(:a, :href => "##{id}", 'data-toggle' => 'tab') do
        yield
      end
    end
  end

  def patternfly_tab_content(id, active, &block)
    content_tag(:div, :id => id, :class => "tab-pane#{active == id ? ' active' : ''}") do
      yield if active == id
    end
  end

  attr_reader :big_iframe
end
