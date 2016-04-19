class ApplicationHelper::ToolbarBuilder
  include MiqAeClassHelper
  def call(toolbar_name)
    build_toolbar(toolbar_name)
  end

  private

  delegate :request, :current_user, :to => :@view_context

  delegate :get_vmdb_config, :role_allows, :model_for_vm, :rbac_common_feature_for_buttons, :to => :@view_context
  delegate :x_tree_history, :x_node, :x_active_tree, :to => :@view_context
  delegate :is_browser?, :is_browser_os?, :to => :@view_context

  def initialize(view_context, view_binding, instance_data)
    @view_context = view_context
    @view_binding = view_binding
    @instance_data = instance_data

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  def eval(code)
    @view_binding.eval(code)
  end

  def safer_eval(code)
    code.to_s =~ /\#{/ ? eval("\"#{code}\"") : code
  end

  ###
  def generic_toolbar(tb_name)
    class_name = 'ApplicationHelper::Toolbar::' + ActiveSupport::Inflector.camelize(tb_name.sub(/_tb$/, ''))
    Kernel.const_get(class_name)
  end

  def build_toolbar(tb_name)
    toolbar = tb_name == "custom_buttons_tb" ? build_custom_buttons_toolbar(@record) : generic_toolbar(tb_name)
    build(toolbar)
  end

  def toolbar_button(props)
    button_class = props[:klass] || ApplicationHelper::Button::Basic
    button_class.new(@view_context, @view_binding, @instance_data, props)
  end

  def build_select_button(bgi, index)
    bs_children = false
    props = toolbar_button(
      :klass  => bgi[:klass],
      :id     => bgi[:buttonSelect],
      :type   => "buttonSelect",
      :img    => img = "#{bgi[:image] ? bgi[:image] : bgi[:buttonSelect]}.png",
      :imgdis => img,
      :icon   => bgi[:icon]
    )
    apply_common_props(props, bgi)

    current_item = props
    current_item[:items] ||= []
    any_visible = false
    bgi[:items].each_with_index do |bsi, bsi_idx|
      if bsi.key?(:separator)
        props = ApplicationHelper::Button::Separator.new(:id => "sep_#{index}_#{bsi_idx}", :hidden => !any_visible)
      else
        next if build_toolbar_hide_button(bsi[:pressed] || bsi[:button]) # Use pressed, else button name
        bs_children = true
        props = toolbar_button(
          :klass    => bsi[:klass],
          :child_id => bsi[:button],
          :id       => bgi[:buttonSelect] + "__" + bsi[:button],
          :type     => "button",
          :img      => img = "#{bsi[:image] || bsi[:button]}.png",
          :imgdis   => img,
          :icon     => bsi[:icon]
        )
        apply_common_props(props, bsi)
        props.calculate_properties
      end
      build_toolbar_save_button(bsi, props) unless bsi.key?(:separator)
      current_item[:items] << props unless props.skip?

      any_visible ||= !props[:hidden] && props[:type] != 'separator'
    end
    current_item[:items].reverse_each do |item|
      break if !item[:hidden] && item[:type] != 'separator'
      item[:hidden] = true if item[:type] == 'separator'
    end
    current_item[:hidden] = !any_visible

    if bs_children
      @sep_added = true                                        # Separator has officially been added
      @sep_needed = true                                       # Need a separator from now on
    end
    current_item
  end

  def apply_common_props(button, input)
    button.update(
      :name    => button[:id],
      :hidden  => button[:hidden] || !!input[:hidden],
      :pressed => input[:pressed],
      :onwhen  => input[:onwhen]
    )

    button[:enabled]   = input[:enabled]
    button[:title]     = safer_eval(input[:title])   unless input[:title].blank?
    button[:text]      = safer_eval(input[:text])    unless input[:text].blank?
    button[:confirm]   = safer_eval(input[:confirm]) unless input[:confirm].blank?
    button[:url_parms] = update_url_parms(safer_eval(input[:url_parms])) unless input[:url_parms].blank?

    if input[:popup] # special behavior: button opens window_url in a new window
      button[:popup] = true
      button[:window_url] = "/#{request.parameters["controller"]}#{input[:url]}"
    end

    dis_title = build_toolbar_disable_button(button[:child_id] || button[:id])
    if dis_title
      button[:enabled] = false
      button[:title]   = dis_title if dis_title.kind_of? String
    end
    button
  end

  def build_normal_button(bgi, index)
    button_hide = build_toolbar_hide_button(bgi[:button])
    if button_hide
      # These buttons need to be present even if hidden as we show/hide them dynamically
      return nil unless %w(perf_refresh perf_reload vm_perf_refresh vm_perf_reload
                           timeline_txt timeline_csv timeline_pdf).include?(bgi[:button])
    end

    @sep_needed = true unless button_hide
    props = toolbar_button(
      :klass  => bgi[:klass],
      :id     => bgi[:button],
      :type   => "button",
      :img    => "#{get_image(bgi[:image], bgi[:button]) ? get_image(bgi[:image], bgi[:button]) : bgi[:button]}.png",
      :imgdis => "#{bgi[:image] || bgi[:button]}.png",
      :icon   => bgi[:icon]
    )
    apply_common_props(props, bgi)

    # set pdf button to be hidden if graphical summary screen is set by default
    props[:hidden] = %w(download_view vm_download_pdf).include?(bgi[:button]) && button_hide

    _add_separator(index)
    props
  end

  def _add_separator(index)
    # Add a separator, if needed, before this button
    if !@sep_added && @sep_needed
      if @groups_added.include?(index) && @groups_added.length > 1
        @toolbar << ApplicationHelper::Button::Separator.new(:id => "sep_#{index}")
        @sep_added = true
      end
    end
    @sep_needed = true # Button was added, need separators from now on
  end

  def build_twostate_button(bgi, index)
    return nil if build_toolbar_hide_button(bgi[:buttonTwoState])

    props = toolbar_button(
      :klass  => bgi[:klass],
      :id     => bgi[:buttonTwoState],
      :type   => "buttonTwoState",
      :img    => img = "#{bgi[:image] ? bgi[:image] : bgi[:buttonTwoState]}.png",
      :imgdis => img,
      :icon   => bgi[:icon]
    )
    apply_common_props(props, bgi)

    props[:selected] = "true" if build_toolbar_select_button(bgi[:buttonTwoState])

    _add_separator(index)
    props
  end

  def build_button(bgi, index)
    props = if bgi.key?(:buttonSelect)
              build_select_button(bgi, index)
            elsif bgi.key?(:button)
              build_normal_button(bgi, index)
            elsif bgi.key?(:buttonTwoState)
              build_twostate_button(bgi, index)
            end

    unless props.nil?
      props.calculate_properties
      @toolbar << build_toolbar_save_button(bgi, props) unless props.skip?
    end
  end

  def build(toolbar)
    @toolbar = []
    @groups_added = []
    @sep_needed = false
    @sep_added = nil

    bg_idx = -1
    toolbar.definition.each_pair do |name, items|
      bg_idx += 1

      @sep_added = false
      if @button_group && (!name.starts_with?(@button_group + "_") &&
        !name.starts_with?("custom") && !name.starts_with?("dialog") &&
        !name.starts_with?("miq_dialog") && !name.starts_with?("custom_button") &&
        !name.starts_with?("instance_") && !name.starts_with?("image_")) &&
         !["record_summary", "summary_main", "summary_download", "tree_main",
           "x_edit_view_tb", "history_main", "ems_container_dashboard"].include?(name)
        next      # Skip if button_group doesn't match
      else
        # keeping track of groups that were not skipped to add separator, else it adds a separator before a button even tho no other groups were shown, i.e. vm sub screens, drift_history
        @groups_added.push(bg_idx)
      end

      items.each do |bgi|
        build_button(bgi, bg_idx)
      end
    end

    @toolbar = nil if @toolbar.empty?
    @toolbar
  end

  def create_custom_button_hash(input, record, options = {})
    options[:enabled]  = "true" unless options.key?(:enabled)
    button             = {}
    button_id          = input[:id]
    button_name        = input[:name].to_s
    button[:button]    = "custom__custom_#{button_id}"
    button[:icon]      = "product product-custom-#{input[:image]} fa-lg"
    button[:text]      = button_name if input[:text_display]
    button[:title]     = input[:description].to_s
    button[:enabled]   = options[:enabled]
    button[:url]       = "button"
    button[:url_parms] = "?id=#{record.id}&button_id=#{button_id}&cls=#{record.class}&pressed=custom_button&desc=#{button_name}"
    button
  end

  def create_raw_custom_button_hash(cb, record)
    obj = {}
    obj[:id]            = cb.id
    obj[:class]         = cb.applies_to_class
    obj[:description]   = cb.description
    obj[:name]          = cb.name
    obj[:image]         = cb.options[:button_image]
    obj[:text_display]  = cb.options.key?(:display) ? cb.options[:display] : true
    obj[:target_object] = record.id.to_i
    obj
  end

  def custom_buttons_hash(record)
    get_custom_buttons(record).collect do |group|
      props = {}
      props[:buttonSelect] = "custom_#{group[:id]}"
      props[:icon]         = "product product-custom-#{group[:image]} fa-lg"
      props[:title]        = group[:description]
      props[:text]         = group[:text] if group[:text_display]
      props[:enabled]      = "true"
      props[:items]        = group[:buttons].collect { |b| create_custom_button_hash(b, record) }

      {:name => "custom_buttons_#{group[:text]}", :items => [props]}
    end
  end

  def build_custom_buttons_toolbar(record)
    # each custom toolbar is an anonymous subclass of this class
    toolbar = Class.new(ApplicationHelper::Toolbar::Basic)
    custom_buttons_hash(record).each do |button_group|
      toolbar.button_group(button_group[:name], button_group[:items])
    end

    service_buttons = record_to_service_buttons(record)
    unless service_buttons.empty?
      buttons = service_buttons.collect { |b| create_custom_button_hash(b, record, :enabled => nil) }
      toolbar.button_group("custom_buttons_", buttons)
    end

    toolbar
  end

  def button_class_name(record)
    case record
    when Service then      "ServiceTemplate"            # Service Buttons are defined in the ServiceTemplate class
    when VmOrTemplate then record.class.base_model.name
    else               record.class.base_class.name
    end
  end

  def service_template_id(record)
    case record
    when Service then         record.service_template_id
    when ServiceTemplate then record.id
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
      group = {}
      group[:id]           = cbs.id
      group[:text]         = cbs.name.split("|").first
      group[:description]  = cbs.description
      group[:image]        = cbs.set_data[:button_image]
      group[:text_display] = cbs.set_data.key?(:display) ? cbs.set_data[:display] : true

      available = CustomButton.available_for_user(current_user, cbs.name) # get all uri records for this user for specified uri set
      available = available.select { |b| cbs.members.include?(b) }            # making sure available_for_user uri is one of the members
      group[:buttons] = available.collect { |cb| create_raw_custom_button_hash(cb, record) }.uniq
      if cbs[:set_data][:button_order] # Show custom buttons in the order they were saved
        ordered_buttons = []
        cbs[:set_data][:button_order].each do |bidx|
          group[:buttons].each do |b|
            if bidx == b[:id] && !ordered_buttons.include?(b)
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
      if role_allows(:feature => "chargeback_reports") && ["chargeback_download_csv", "chargeback_download_pdf",
                                                           "chargeback_download_text", "chargeback_report_only"].include?(id)
        return false
      end
    when :cb_rates_tree
      if role_allows(:feature => "chargeback_rates") && ["chargeback_rates_copy", "chargeback_rates_delete",
                                                         "chargeback_rates_edit", "chargeback_rates_new"].include?(id)
        return false
      end
    end
    true
  end

  def build_toolbar_hide_button_ops(id)
    case x_active_tree
    when :settings_tree
      return ["schedule_run_now"].include?(id) ? true : false
    when :diagnostics_tree
      case @sb[:active_tab]
      when "diagnostics_audit_log"
        return ["fetch_audit_log", "refresh_audit_log"].include?(id) ? false : true
      when "diagnostics_collect_logs"
        return %(collect_current_logs collect_logs log_depot_edit
                 zone_collect_current_logs zone_collect_logs
                 zone_log_depot_edit).include?(id) ? false : true
      when "diagnostics_evm_log"
        return ["fetch_log", "refresh_log"].include?(id) ? false : true
      when "diagnostics_production_log"
        return ["fetch_production_log", "refresh_production_log"].include?(id) ? false : true
      when "diagnostics_roles_servers", "diagnostics_servers_roles"
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
        return ["refresh_server_summary", "restart_server"].include?(id) ? false : true
      when "diagnostics_workers"
        return ["refresh_workers", "restart_workers"].include?(id) ? false : true
      else
        return true
      end
    when :rbac_tree
      common_buttons = %w(rbac_project_add rbac_tenant_add)
      feature = common_buttons.include?(id) ? rbac_common_feature_for_buttons(id) : id
      return true unless role_allows(:feature => feature)
      return true if common_buttons.include?(id) && @record.project?
      return false
    when :vmdb_tree
      return ["db_connections", "db_details", "db_indexes", "db_settings"].include?(@sb[:active_tab]) ? false : true
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
      if %w(saved_report_delete).include?(id)
        return true unless role_allows(:feature => id)
      end
      case id
      when "reload"
        return x_node != "root"
      when "view_graph", "view_hybrid", "view_tabular"
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
      return true unless @record.validate_reconfigure
    end
    false
  end

  # Determine if a button should be hidden
  def build_toolbar_hide_button(id)
    return false if id.start_with?('history_')
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

    return true if %w(container_image_registry_edit container_image_registry_delete
                      container_image_registry_new).include?(id) &&
                   (@record.kind_of?(ContainerImageRegistry) || @record.nil?)

    return true if %w(persistent_volume_edit persistent_volume_delete persistent_volume_new).include?(id) &&
                   (@record.kind_of?(PersistentVolume) || @record.nil?)

    return true if %w(container_build_edit container_build_delete container_build_new).include?(id) &&
                   (@record.kind_of?(ContainerBuild) || @record.nil?)

    # hide edit button for MiqRequest instances of type ServiceReconfigureRequest/ServiceTemplateProvisionRequest
    # TODO: extend .is_available? support via refactoring task to cover this scenario
    return true if id == 'miq_request_edit' &&
                   %w(ServiceReconfigureRequest ServiceTemplateProvisionRequest).include?(@miq_request.try(:type))

    # hide power management buttons for Openstack::InfraManager
    return true if %w(host_standby host_shutdown host_reboot host_start host_stop host_reset).include?(id) &&
                   @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)

    # hide compliance check and comparison buttons rendered for orchestration stack instances
    return true if @record.kind_of?(OrchestrationStack) && @display == "instances" &&
                   %w(instance_check_compliance instance_compare).include?(id)

    # don't hide view buttons in toolbar
    return false if %( view_grid view_tile view_list view_dashboard view_summary refresh_log fetch_log common_drift
      download_text download_csv download_pdf download_view vm_download_pdf
      tree_large tree_small).include?(id) && !%w(miq_policy_rsop ops).include?(@layout)

    # dont hide back to summary button button when not in explorer
    return false if id == "show_summary" && !@explorer

    # need to hide add buttons when on sub-list view screen of a CI.
    return true if id.ends_with?("_new", "_discover") &&
                   @lastaction == "show" && @display != "main"

    if id == "summary_reload"                             # Show reload button if
      return @explorer && # we are in explorer and
        ((@record && #    1) we are on a record and
         !["miq_policy_rsop"].include?(@layout) && # @layout is not one of these
         !["details", "item"].include?(@showtype)) || #       not showing list or single sub screen item i.e VM/Users
         @lastaction == "show_list") ? # or 2) selected node shows a list of records
        false : true
    end

    # user can see the buttons if they can get to Policy RSOP/Automate Simulate screen
    return false if ["miq_ae_tools"].include?(@layout)

    # hide this button when in custom buttons tree on ci node, this button is added in toolbar to show on Buttons folder node in CatalogItems tree
    return true if id == "ab_button_new" && x_active_tree == :ab_tree && x_node.split('_').length == 2 && x_node.split('_')[0] == "xx-ab"

    # Form buttons don't need RBAC check
    return false if ["button_add"].include?(id) && @edit && !@edit[:rec_id]

    # Form buttons don't need RBAC check
    return false if ["button_save", "button_reset"].include?(id) && @edit && @edit[:rec_id]

    # Form buttons don't need RBAC check
    return false if ["button_cancel"].include?(id)

    # buttons on compare/drift screen are allowed if user has access to compare/drift
    return false if id.starts_with?("compare_", "drift_", "comparemode_", "driftmode_")

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

    if @layout == "pxe" || id.starts_with?("pxe_", "customization_template_")
      res = build_toolbar_hide_button_pxe(id)
      return res
    end

    if @layout == "report"
      res = build_toolbar_hide_button_report(id)
      return res
    end

    return false if role_allows(:feature => "my_settings_time_profiles") && @layout == "configuration" &&
                    @tabform == "ui_4"

    return false if id.starts_with?("miq_capacity_") && @sb[:active_tab] == "report"

    # hide button if id is approve/deny and miq_request_approval feature is not allowed.
    return true if !role_allows(:feature => "miq_request_approval") && ["miq_request_approve", "miq_request_deny"].include?(id)

    # don't check for feature RBAC if id is miq_request_approve/deny
    unless %w(miq_policy catalogs).include?(@layout)
      return true if !role_allows(:feature => id) && !["miq_request_approve", "miq_request_deny"].include?(id) &&
                     id !~ /^history_\d*/ &&
                     !id.starts_with?("dialog_") && !id.starts_with?("miq_task_")
    end

    # Check buttons with other restriction logic
    case id
    when "dialog_add_box", "dialog_add_element", "dialog_add_tab", "dialog_res_discard", "dialog_resource_remove"
      return true unless @edit
      return true if id == "dialog_res_discard" && @sb[:edit_typ] != "add"
      return true if id == "dialog_resource_remove" && (@sb[:edit_typ] == "add" || x_node == "root")
      nodes = x_node.split('_')
      return true if id == "dialog_add_tab" && (nodes.length > 2)
      return true if id == "dialog_add_box" && (nodes.length < 2 || nodes.length > 3)
      return true if id == "dialog_add_element" && (nodes.length < 3 || nodes.length > 4)
    when "dialog_copy", "dialog_delete", "dialog_edit", "dialog_new"
      return true if @edit && @edit[:current]
    when "miq_task_canceljob"
      return true unless ["all_tasks", "all_ui_tasks"].include?(@layout)
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
    return true if (id == "ems_infra_scale" || id == "ems_infra_scaledown") &&
                   (@record.class != ManageIQ::Providers::Openstack::InfraManager ||
                    !role_allows(:feature => "ems_infra_scale") ||
                   (@record.class == ManageIQ::Providers::Openstack::InfraManager && @record.orchestration_stacks.count == 0))

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
        return true unless role_allows(:feature => "condition_edit")
      when "condition_copy"
        return true if x_active_tree != :condition_tree || !role_allows(:feature => "condition_new")
      when "condition_delete"
        return true if x_active_tree != :condition_tree || !role_allows(:feature => "condition_delete")
      when "condition_policy_copy"
        return true if x_active_tree == :condition_tree || !role_allows(:feature => "condition_new")
      when "condition_remove"
        return true if x_active_tree == :condition_tree || !role_allows(:feature => "condition_delete")
      end
    when "CustomButton"
      case id
      when "ab_button_edit", "ab_button_delete", "ab_button_simulate"
        return !role_allows_button_manipulation if x_active_tree == :sandt_tree
      end
    when "CustomButtonSet"
      case id
      when "ab_group_edit", "ab_group_delete", "ab_button_new"
        return !role_allows_button_manipulation if x_active_tree == :sandt_tree
      end
    when "Host"
      case id
      when "host_protect"
        return true unless @record.smart?
      when "host_refresh"
        return true unless @record.is_refreshable?
      when "host_scan"
        return true unless @record.is_scannable?
      when "host_shutdown", "host_standby", "host_reboot",
          "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"
        btn_id = id.split("_")[1..-1].join("_")
        return true unless @record.is_available?(btn_id.to_sym)
      when "perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "MiqAction"
      case id
      when "action_edit"
        return true unless role_allows(:feature => "action_edit")
      when "action_delete"
        return true unless role_allows(:feature => "action_delete")
      end
    when "MiqAeClass", "MiqAeDomain", "MiqAeField", "MiqAeInstance", "MiqAeMethod", "MiqAeNamespace"
      return false if MIQ_AE_COPY_ACTIONS.include?(id) && User.current_tenant.any_editable_domains? && MiqAeDomain.any_unlocked?
      case id
      when "miq_ae_domain_lock"
        return true unless editable_domain?(@record)
      when "miq_ae_domain_unlock"
        return true if editable_domain?(@record) || @record.priority.to_i == 0
      else
        return true unless editable_domain?(@record)
      end
    when "MiqAlert"
      case id
      when "alert_copy"
        return true unless role_allows(:feature => "alert_copy")
      when "alert_edit"
        return true unless role_allows(:feature => "alert_edit")
      when "alert_delete"
        return true unless role_allows(:feature => "alert_delete")
      end
    when "MiqAlertSet"
      case id
      when "alert_profile_edit"
        return true unless role_allows(:feature => "alert_profile_edit")
      when "alert_profile_delete"
        return true unless role_allows(:feature => "alert_profile_delete")
      end
    when "MiqEventDefinition"
      case id
      when "event_edit"
        return true if x_active_tree == :event_tree || !role_allows(:feature => "event_edit")
      end
    when "MiqPolicy"
      case id
      when "condition_edit", "policy_edit", "policy_edit_conditions"
        return true unless role_allows(:feature => "policy_edit")
      when "policy_edit_conditions"
        return true unless role_allows(:feature => "policy_edit_conditions")
      when "policy_edit_events"
        return true if !role_allows(:feature => "policy_edit") ||
                       @policy.mode == "compliance"
      when "policy_copy"
        return true if !role_allows(:feature => "policy_copy") ||
                       x_active_tree != :policy_tree
      when "policy_delete"
        return true if !role_allows(:feature => "policy_delete") ||
                       x_active_tree != :policy_tree
      end
    when "MiqPolicySet"
      case id
      when "profile_edit"
        return true unless role_allows(:feature => "profile_edit")
      when "profile_delete"
        return true unless role_allows(:feature => "profile_delete")
      end
    when "MiqRequest"
      # Don't hide certain buttons on AutomationRequest screen
      return true if @record.resource_type == "AutomationRequest" &&
                     !["miq_request_approve", "miq_request_deny", "miq_request_delete"].include?(id)

      case id
      when "miq_request_approve", "miq_request_deny"
        return true if ["approved", "denied"].include?(@record.approval_state) || @showtype == "miq_provisions"
      when "miq_request_edit"
        return true if current_user.name != @record.requester_name || ["approved", "denied"].include?(@record.approval_state)
      when "miq_request_copy"
        resource_types_for_miq_request_copy = %w(MiqProvisionRequest
                                                 MiqHostProvisionRequest
                                                 MiqProvisionConfiguredSystemRequest)
        return true if !resource_types_for_miq_request_copy.include?(@record.resource_type) ||
                       ((current_user.name != @record.requester_name ||
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
    when "MiqTemplate"
      case id
      when "miq_template_clone"
        return true unless @record.is_available?(:clone)
      when "miq_template_policy_sim", "miq_template_protect"
        return true if @record.host && @record.host.vmm_product.downcase == "workstation"
      when "miq_template_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "miq_template_scan", "image_scan"
        return true unless @record.is_available?(:smartstate_analysis) || @record.is_available_now_error_message(:smartstate_analysis)
        return true unless @record.has_proxy?
      when "miq_template_refresh", "miq_template_reload"
        return true unless @perf_options[:typ] == "realtime"
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
    when "Service", "ServiceOrchestration"
      return build_toolbar_hide_button_service(id)
    when "ServiceTemplate"
      case id
      when "ab_group_new", "ab_button_new"
        return !role_allows_button_manipulation
      when /^history_\d*/
        return false
      else
        return !role_allows(:feature => id)
      end
    when "Vm"
      case id
      when "vm_clone"
        return true unless @record.is_available?(:clone)
      when "vm_collect_running_processes"
        return true if (@record.retired || @record.current_state == "never") && !@record.is_available?(:collect_running_processes)
      when "vm_guest_startup", "vm_start", "instance_start", "instance_resume"
        return true unless @record.is_available?(:start)
      when "vm_guest_standby"
        return true unless @record.is_available?(:standby_guest)
      when "vm_guest_shutdown", "instance_guest_shutdown"
        return true unless @record.is_available?(:shutdown_guest)
      when "vm_guest_restart", "instance_guest_restart"
        return true unless @record.is_available?(:reboot_guest)
      when "vm_migrate"
        return true unless @record.is_available?(:migrate)
      when "vm_publish"
        return true unless @record.is_available?(:publish)
      when "vm_reconfigure"
        return true unless @record.reconfigurable?
      when "vm_retire"
        return true unless @record.is_available?(:retire)
      when "vm_retire_now"
        return true unless @record.is_available?(:retire_now)
      when "vm_stop", "instance_stop"
        return true unless @record.is_available?(:stop)
      when "vm_reset", "instance_reset"
        return true unless @record.is_available?(:reset)
      when "vm_suspend", "instance_suspend"
        return true unless @record.is_available?(:suspend)
      when "instance_shelve"
        return true unless @record.is_available?(:shelve)
      when "instance_shelve_offload"
        return true unless @record.is_available?(:shelve_offload)
      when "instance_pause"
        return true unless @record.is_available?(:pause)
      when "instance_terminate"
        return true unless @record.is_available?(:terminate)
      when "vm_policy_sim", "vm_protect"
        return true if @record.host && @record.host.vmm_product.to_s.downcase == "workstation"
      when "vm_refresh"
        return true if @record && !@record.ext_management_system && !(@record.host && @record.host.vmm_product.downcase == "workstation")
      when "vm_scan", "instance_scan"
        return true unless @record.is_available?(:smartstate_analysis) || @record.is_available_now_error_message(:smartstate_analysis)
        return true unless @record.has_proxy?
      when "perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"
        return true unless @perf_options[:typ] == "realtime"
      end
    when "OrchestrationTemplate", "OrchestrationTemplateCfn", "OrchestrationTemplateHot", "OrchestrationTemplateAzure"
      return true unless role_allows(:feature => id)
    when "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem", "ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem"
      case id
      when "configured_system_provision"
        return true unless @record.provisionable?
      end
    when "NilClass"
      case id
      when "ab_group_new", "ab_button_new", "ab_group_reorder"
        return !role_allows_button_manipulation if x_active_tree == :sandt_tree
      when "action_new"
        return true unless role_allows(:feature => "action_new")
      when "alert_profile_new"
        return true unless role_allows(:feature => "alert_profile_new")
      when "alert_new"
        return true unless role_allows(:feature => "alert_new")
      when "condition_new"
        return true unless role_allows(:feature => "condition_new")
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
      when "timeline_csv"
        return true unless @report
      when "timeline_pdf"
        return true unless @report
      when "timeline_txt"
        return true unless @report
      when "vm_clone", "vm_publish", "vm_migrate", "vm_retire", "vm_retire_now"
        if @sb[:trees][:vandt_tree].present? &&
           (@sb[:trees][:vandt_tree][:active_node] == "xx-arch" ||
            @sb[:trees][:vandt_tree][:active_node] == "xx-orph")
          return true
        end
      else
        return !role_allows(:feature => id)
      end
    end
    false  # No reason to hide, allow the button to show
  end

  def role_allows_button_manipulation
    %w(catalogitem_new catalogitem_edit atomic_catalogitem_new atomic_catalogitem_edit).any? do |feature|
      role_allows(:feature => feature)
    end
  end

  # Determine if a button should be disabled
  def build_toolbar_disable_button(id)
    return true if id.starts_with?("view_") && id.ends_with?("textual")  # Summary view buttons
    return true if @gtl_type && id.starts_with?("view_") && id.ends_with?(@gtl_type)  # GTL view buttons
    return true if id == "history_1" && x_tree_history.length < 2 # Need 1 child button to show parent
    return true if id == "view_dashboard" && (@showtype == "dashboard")
    return true if id == "view_summary" && (@showtype != "dashboard")

    # Form buttons check if anything on form has changed
    return true if ["button_add", "button_save", "button_reset"].include?(id) && !@changed

    # need to add this here, since this button is on list view screen
    if @layout == "pxe" && id == "iso_datastore_new" && ManageIQ::Providers::Redhat::InfraManager.datastore?
      return "No #{ui_lookup(:tables => "ext_management_system")} are available to create an ISO Datastore on"
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
        return "No Timeline data has been collected for this Availability Zone" unless @record.has_events? # || @record.has_events?(:policy_events), may add this check back in later
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
        return "This Host can not be provisioned because the MAC address is not known" unless @record.mac_address
        count = PxeServer.all.size
        return "No PXE Servers are available for Host provisioning" if count <= 0
      when "host_refresh"
        return @record.is_refreshable_now_error_message unless @record.is_refreshable_now?
      when "host_scan"
        return @record.is_scannable_now_error_message unless @record.is_scannable_now?
      when "host_timeline"
        return "No Timeline data has been collected for this Host" unless @record.has_events? || @record.has_events?(:policy_events)
      when "host_shutdown"
        return @record.is_available_now_error_message(:shutdown) if @record.is_available_now_error_message(:shutdown)
      when "host_restart"
        return @record.is_available_now_error_message(:reboot) if @record.is_available_now_error_message(:reboot)
      end
    when "Container"
      case id
      when "container_timeline"
        return "No Timeline data has been collected for this Container" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "ContainerNode"
      case id
      when "container_node_timeline"
        return "No Timeline data has been collected for this Node" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "ContainerGroup"
      case id
      when "container_group_timeline"
        return "No Timeline data has been collected for this Pod" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "ContainerReplicator"
      case id
      when "container_replicator_timeline"
        return "No Timeline data has been collected for this Replicator" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "ContainerProject"
      case id
      when "container_project_timeline"
        return "No Timeline data has been collected for this Project" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "MiqAction"
      case id
      when "action_edit"
        return "Default actions can not be changed." if @record.action_type == "default"
      when "action_delete"
        return "Default actions can not be deleted." if @record.action_type == "default"
        return "Actions assigned to Policies can not be deleted" if @record.miq_policies.length > 0
      end
    when "MiqAeDomain", "MiqAeNamespace"
      editable_domain = editable_domain?(@record)
      case id
      when "miq_ae_domain_delete"
        return "Read Only Domain cannot be deleted." unless editable_domain
      when "miq_ae_domain_edit"
        return "Read Only Domain cannot be edited" unless editable_domain
      when "miq_ae_domain_lock"
        return "Domain is Locked." unless editable_domain
      when "miq_ae_domain_unlock"
        return "Domain is Unlocked." if editable_domain
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
    when "MiqRequest"
      case id
      when "miq_request_delete"
        requester = current_user
        return false if requester.admin_user?
        return _("Users are only allowed to delete their own requests") if requester.name != @record.requester_name
        if %w(approved denied).include?(@record.approval_state)
          return _("%{approval_states} requests cannot be deleted") %
            {:approval_states => @record.approval_state.titleize}
        end
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
        return "Cannot collect current logs unless the #{ui_lookup(:table => "miq_server")} is started" unless @record.started?
        return "Log collection is already in progress for this #{ui_lookup(:table => "miq_server")}" if @record.log_collection_active_recently?
        return "Log collection requires the Log Depot settings to be configured" unless @record.log_file_depot
      when "delete_server"
        return "Server #{@record.name} [#{@record.id}] can only be deleted if it is stopped or has not responded for a while" unless @record.is_deleteable?
      when "restart_workers"
        return "Select a worker to restart" if @sb[:selected_worker_id].nil?
      end
    when "MiqWidget"
      case id
      when "widget_generate_content"
        return "Widget has to be assigned to a dashboard to generate content" if @record.memberof.count <= 0
        return "This Widget content generation is already running or queued up" if @widget_running
      end
    when "MiqWidgetSet"
      case id
      when "db_delete"
        return "Default Dashboard cannot be deleted" if @db.read_only
      end
    when "OrchestrationStack"
      case id
      when "orchestration_stack_retire_now"
        return "Orchestration Stack is already retired" if @record.retired == true
      end
    when "OrchestrationTemplateCfn", "OrchestrationTemplateHot", "OrchestrationTemplateAzure"
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
        return "No Capacity & Utilization data has been collected for this #{ui_lookup(:table => "storage")}" unless @record.has_perf_data?
      when "storage_delete"
        return "Only #{ui_lookup(:table => "storage")} without VMs and Hosts can be removed" if @record.vms_and_templates.length > 0 || @record.hosts.length > 0
      when "storage_scan"
        return @record.is_available_now_error_message(:smartstate_analysis) unless @record.is_available?(:smartstate_analysis)
      end
    when "Tenant"
      return "Default Tenant can not be deleted" if @record.parent.nil? && id == "rbac_tenant_delete"
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
      when "instance_perf", "vm_perf", "container_perf"
        return "No Capacity & Utilization data has been collected for this VM" unless @record.has_perf_data?
      when "instance_check_compliance", "vm_check_compliance"
        model = model_for_vm(@record).to_s
        return "No Compliance Policies assigned to this #{model == "ManageIQ::Providers::InfraManager::Vm" ? "VM" : ui_lookup(:model => model)}" unless @record.has_compliance_policies?
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
        return "#{@record.kind_of?(ManageIQ::Providers::CloudManager::Vm) ? "Instance" : "VM"} is already retired" if @record.retired == true
      when "vm_scan", "instance_scan"
        return @record.is_available_now_error_message(:smartstate_analysis) unless @record.is_available?(:smartstate_analysis)
        return @record.active_proxy_error_message unless @record.has_active_proxy?
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
      when "image_check_compliance", "miq_template_check_compliance"
        return "No Compliance Policies assigned to this #{ui_lookup(:model => model_for_vm(@record).to_s)}" unless @record.has_compliance_policies?
      when "miq_template_perf"
        return "No Capacity & Utilization data has been collected for this Template" unless @record.has_perf_data?
      when "miq_template_scan", "image_scan"
        return @record.is_available_now_error_message(:smartstate_analysis) unless @record.is_available?(:smartstate_analysis)
        return @record.active_proxy_error_message unless @record.has_active_proxy?
      when "miq_template_timeline"
        return "No Timeline data has been collected for this Template" unless @record.has_events? || @record.has_events?(:policy_events)
      end
    when "Zone"
      case id
      when "zone_collect_logs", "zone_collect_current_logs"
        return "Cannot collect current logs unless there are started #{ui_lookup(:tables => "miq_servers")} in the Zone" unless @record.any_started_miq_servers?
        return "This Zone do not have Log Depot settings configured, collection not allowed" unless @record.log_file_depot
        return "Log collection is already in progress for one or more #{ui_lookup(:tables => "miq_servers")} in this Zone" if @record.log_collection_active_recently?
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
        return "No System Image Types available, Customization Template cannot be added" if @pxe_image_types_count <= 0
      # following 2 are checks for buttons in Reports/Dashboard accordion
      when "db_new"
        return "Only #{MAX_DASHBOARD_COUNT} Dashboards are allowed for a group" if @widgetsets.length >= MAX_DASHBOARD_COUNT
      when "db_seq_edit"
        return "There should be atleast 2 Dashboards to Edit Sequence" if @widgetsets.length <= 1
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
    elsif MiqRequest.descendants.include?(record.class)
      record.class.base_class.name
    else
      klass = case record
              when ContainerNode, ContainerGroup, Container then record.class.base_class
              when Host, ExtManagementSystem                then record.class.base_class
              when VmOrTemplate                             then record.class.base_model
              else                                               record.class
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
    false
  end

  def controller_restful?
    # want to be able to cache false, so no ||=
    return @_restful_cache unless @_restful_cache.nil?

    @_restful_cache = (
      obj = @view_binding.receiver

      if obj.respond_to? :controller
        obj.controller.try(:restful?)
      else
        obj.try(:restful?)
      end
    )
  end

  def url_for_button(name, url_tpl, controller_restful)
    url = safer_eval(url_tpl)

    if %w(view_grid view_tile view_list).include?(name) && controller_restful && url =~ %r{^\/(\d+|\d+r\d+)\?$}
      # handle restful routes - we want just / if the url is just an id
      url = '/'
    end

    url
  end

  def build_toolbar_save_button(item, props)
    props[:url] = url_for_button(props[:id], item[:url], controller_restful?) if item[:url]
    props[:explorer] = true if @explorer && !item[:url] # Add explorer = true if ajax button
    props
  end

  def update_url_parms(url_parm)
    return url_parm unless url_parm =~ /=/

    keep_parms = %w(bc escape menu_click sb_controller)
    query_string = Rack::Utils.parse_query URI("?#{request.query_string}").query
    query_string.delete_if { |k, _v| !keep_parms.include? k }

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
end
