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
  module_function :role_allows
  public :role_allows

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
    when "ManageIQ::Providers::CloudManager::Template", "ManageIQ::Providers::CloudManager::Vm", "ManageIQ::Providers::InfraManager::Template", "ManageIQ::Providers::InfraManager::Vm"
      VmOrTemplate
    else
      self.class.model
    end
  end

  def url_for_record(record, action="show") # Default action is show
    @id = to_cid(record.id)
    if record.kind_of?(VmOrTemplate)
      return url_for_db(controller_for_vm(model_for_vm(record)), action)
    elsif record.class.respond_to?(:db_name)
      return url_for_db(record.class.db_name, action)
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
    _toolbar_builder.call(tb_name)
  end

  def _toolbar_builder
    ToolbarBuilder.new(
      self,
      binding,
      :active                => @active,
      :button_group          => @button_group,
      :changed               => @changed,
      :condition             => @condition,
      :db                    => @db,
      :display               => @display,
      :edit                  => @edit,
      :explorer              => @explorer,
      :ght_type              => @ght_type,
      :gtl_buttons           => @gtl_buttons,
      :gtl_type              => @gtl_type,
      :html                  => @html,
      :is_redhat             => @is_redhat,
      :lastaction            => @lastaction,
      :layout                => @layout,
      :miq_request           => @miq_request,
      :perf_options          => @perf_options,
      :policy                => @policy,
      :pxe_image_types_count => @pxe_image_types_count,
      :record                => @record,
      :report                => @report,
      :report_result_id      => @report_result_id,
      :resolve               => @resolve,
      :sb                    => @sb,
      :selected_zone         => @selected_zone,
      :settings              => @settings,
      :showtype              => @showtype,
      :tabform               => @tabform,
      :usage_options         => @usage_options,
      :widget_running        => @widget_running,
      :widgetsets            => @widgetsets,
      :zgraph                => @zgraph,
    )
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
    _toolbar_chooser.call
  end

  def _toolbar_chooser
    ToolbarChooser.new(
      self,
      :alert_profiles => @alert_profiles,
      :button_group   => @button_group,
      :conditions     => @conditions,
      :dialog         => @dialog,
      :display        => @display,
      :explorer       => @explorer,
      :in_a_form      => @in_a_form,
      :lastaction     => @lastaction,
      :layout         => @layout,
      :nodetype       => @nodetype,
      :policies       => @policies,
      :record         => @record,
      :report         => @report,
      :sb             => @sb,
      :tabform        => @tabform,
      :view           => @view,
    )
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
    if record.kind_of?(ManageIQ::Providers::CloudManager)
      ManageIQ::Providers::CloudManager
    elsif record.kind_of?(EmsContainer)
      EmsContainer
    else
      ManageIQ::Providers::InfraManager
    end
  end

  def model_for_vm(record)
    raise "Record is not VmOrTemplate class" unless record.kind_of?(VmOrTemplate)
    if record.kind_of?(ManageIQ::Providers::CloudManager::Vm)
      ManageIQ::Providers::CloudManager::Vm
    elsif record.kind_of?(ManageIQ::Providers::InfraManager::Vm)
      ManageIQ::Providers::InfraManager::Vm
    elsif record.kind_of?(ManageIQ::Providers::CloudManager::Template)
      ManageIQ::Providers::CloudManager::Template
    elsif record.kind_of?(ManageIQ::Providers::InfraManager::Template)
      ManageIQ::Providers::InfraManager::Template
    end
  end

  def controller_for_vm(model)
    case model.to_s
      when "ManageIQ::Providers::CloudManager::Template", "ManageIQ::Providers::CloudManager::Vm"
        "vm_cloud"
      when "ManageIQ::Providers::InfraManager::Template", "ManageIQ::Providers::InfraManager::Vm"
        "vm_infra"
      else
        "vm_or_template"
    end
  end

  def vm_model_from_active_tree(tree)
    case tree
      when :instances_filter_tree
        "ManageIQ::Providers::CloudManager::Vm"
      when :images_filter_tree
        "ManageIQ::Providers::CloudManager::Template"
      when :vms_filter_tree
        "ManageIQ::Providers::InfraManager::Vm"
      when :templates_filter_tree
        "ManageIQ::Providers::InfraManager::Template"
      when :instances_filter_tree
        "ManageIQ::Providers::CloudManager::Vm"
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
    attributes = vm_cloud_attributes(record) if record.kind_of?(ManageIQ::Providers::CloudManager::Vm)
    attributes ||= vm_infra_attributes(record) if record.kind_of?(ManageIQ::Providers::InfraManager::Vm)
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

  def miq_tab_header(id, active = nil, options = {}, &block)
    content_tag(:li, :class => "#{options[:class]} #{active == id ? 'active' : ''}", :id => "#{id}_tab") do
      content_tag(:a, :href => "##{id}", 'data-toggle' => 'tab') do
        yield
      end
    end
  end

  def miq_tab_content(id, active = nil, options = {}, &block)
    content_tag(:div, :id => id, :class => "tab-pane #{options[:class]} #{active == id ? 'active' : ''}") do
      yield
    end
  end

  def controller_referrer?
    controller_name == Rails.application.routes.recognize_path(request.referrer)[:controller]
  end

  def breadcrumb_prohibited_for_action?
    !%w(accordion_select tree_select).include?(action_name)
  end

  def my_server_id
    my_server.id
  end

  def my_zone_name
    my_server.my_zone
  end

  def my_server
    @my_server ||= MiqServer.my_server(true)
  end

  def vm_explorer_tree?
    [:filter, :images, :instances, :templates_images_filter, :vandt, :vms_instances_filter].include?(x_tree[:type])
  end

  def show_advanced_search?
    x_tree && ((vm_explorer_tree? && !@record) || @show_adv_search)
  end

  attr_reader :big_iframe
end
