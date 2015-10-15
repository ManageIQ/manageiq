class ApplicationHelper::ToolbarBuilder
  include MiqAeClassHelper
  def call(toolbar_name)
    build_toolbar_buttons_and_xml(toolbar_name)
  end

  private

  delegate :request, :current_user, :to => :@view_context

  delegate :get_vmdb_config, :role_allows, :model_for_vm, :rbac_common_feature_for_buttons, :to => :@view_context
  delegate :x_tree_history, :x_node, :x_active_tree, :to => :@view_context
  delegate :is_browser?, :is_browser_os?, :to => :@view_context

  def initialize(view_context, view_binding, instance_data)
    @view_context = view_context
    @view_binding = view_binding

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  def eval(code)
    @view_binding.eval(code)
  end

  ###

  def create_custom_button_hash(input, record, options = {})
    options[:enabled]  = "true" unless options.key?(:enabled)
    button             = {}
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
      props[:image]        = "custom-#{group[:image]}"
      props[:title]        = group[:description]
      props[:text]         = group[:text] if group[:text_display]
      props[:enabled]      = "true"
      props[:items]        = group[:buttons].collect { |b| create_custom_button_hash(b, record) }

      {:name => "custom_buttons_#{group[:text]}", :items => [props]}
    end
  end

  def build_custom_buttons_toolbar(record)
    toolbar_hash = {:button_groups => custom_buttons_hash(record)}

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


  def build_toolbar_hide_button_service(id)
    case id
    when "service_reconfigure"
      ra = @record.service_template.resource_actions.find_by_action('Reconfigure') if @record.service_template
      return true if ra.nil? || ra.dialog_id.nil? || ra.fqname.blank?
    end
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

end
