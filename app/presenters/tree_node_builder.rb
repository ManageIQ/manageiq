class TreeNodeBuilder
  include MiqAeClassHelper

  # method to build non-explorer tree nodes
  def self.generic_tree_node(key, text, image, tip = nil, options = {})
    text = ERB::Util.html_escape(text) unless text.html_safe?
    node = {
      :key   => key,
      :title => text,
    }
    node[:icon]         = ActionController::Base.helpers.image_path("100/#{image}") if image
    node[:addClass]     = options[:style_class]      if options[:style_class]
    node[:cfmeNoClick]  = true                       if options[:cfme_no_click]
    node[:expand]       = options[:expand]           if options[:expand]
    node[:hideCheckbox] = true                       if options[:hideCheckbox]
    node[:noLink]       = true                       if options[:noLink]
    node[:select]       = options[:select]           if options[:select]
    node[:tooltip]      = ERB::Util.html_escape(tip) if tip && !tip.html_safe?
    node
  end

  # Options used:
  #   :type       -- Type of tree, i.e. :handc, :vandt, :filtered, etc
  #   :open_nodes -- Tree node ids of currently open nodes
  #   FIXME: fill in missing docs
  #
  def self.build(object, parent_id, options)
    builder = new(object, parent_id, options)
    builder.build
  end

  def self.build_id(object, parent_id, options)
    builder = new(object, parent_id, options)
    builder.build_id
  end

  def initialize(object, parent_id, options)
    @object, @parent_id, @options = object, parent_id, options
  end

  attr_reader :object, :parent_id, :options

  def build_id
    object.kind_of?(Hash) ? build_hash_id : build_object_id
  end

  # FIXME: This is a rubocop disaster... fixed the alignment with the params,
  # but that is about as far as I was willing to go with this one...
  #
  # rubocop:disable LineLength, Style/BlockDelimiters, Style/BlockEndNewline
  # rubocop:disable Style/Lambda, Style/AlignParameters, Style/MultilineBlockLayout
  BUILD_NODE_HASH = {
    "AssignedServerRole"     => -> { assigned_server_role_node(object) },
    "AvailabilityZone"       => -> { generic_node(object.name,
                                                "availability_zone.png",
                                                _("Availability Zone: %{name}") % {:name => object.name}) },
    "ConfigurationScript"    => -> { generic_node(object.name,
                                               "configuration_script.png",
                                               "Ansible Tower Job Template: #{object.name}") },
    "ExtManagementSystem"    => -> {
      # TODO: This should really leverage .base_model on an EMS
      prefix_model =
        case object
        when EmsCloud then "EmsCloud"
        when EmsInfra then "EmsInfra"
        else               "ExtManagementSystem"
        end

      generic_node(object.name, "vendor-#{object.image_name}.png", "#{ui_lookup(:model => prefix_model)}: #{object.name}") },
    "ChargebackRate"         => -> { generic_node(object.description, "chargeback_rate.png") },
    "Classification"         => -> { classification_node },
    "Compliance"             => -> {
      name = "<b>" + _("Compliance Check on: ") + "</b>" + format_timezone(object.timestamp, Time.zone, 'gtl')
      generic_node(name.html_safe, "#{object.compliant ? "check" : "x"}.png") },
    "ComplianceDetail"       => -> {
      name = "<b>" + _("Policy: ") + "</b>" + object.miq_policy_desc
      generic_node(name.html_safe, "#{object.miq_policy_result ? "check" : "x"}.png") },
    "Condition"              => -> { generic_node(object.description, "miq_condition.png") },
    "ConfigurationProfile"   => -> { configuration_profile_node(object.name, "configuration_profile.png",
                                                              _("Configuration Profile: %{name}") % {:name => object.name}) },
    "ConfiguredSystem"       => -> { generic_node(object.hostname,
                                                "configured_system.png",
                                                _("Configured System: %{hostname}") % {:hostname => object.hostname}) },
    "Container"              => -> { generic_node(object.name, "container.png") },
    "CustomButton"           => -> { generic_node(object.name,
                                                object.options && object.options[:button_image] ? "custom-#{object.options[:button_image]}.png" : "leaf.gif",
                                                _("Button: %{button_description}") % {:button_description => object.description}) },
    "CustomButtonSet"        => -> { custom_button_set_node },
    "CustomizationTemplate"  => -> { generic_node(object.name, "customizationtemplate.png") },
    "Dialog"                 => -> { generic_node(object.label, "dialog.png") },
    "DialogTab"              => -> { generic_node(object.label, "dialog_tab.png") },
    "DialogGroup"            => -> { generic_node(object.label, "dialog_group.png") },
    "DialogField"            => -> { generic_node(object.label, "dialog_field.png") },
    "EmsFolder"              => -> { ems_folder_node },
    "EmsCluster"             => -> { generic_node(object.name, "cluster.png", "#{ui_lookup(:table => "ems_cluster")}: #{object.name}") },
    "GuestDevice"            => -> { guest_node(object) },
    "Host"                   => -> { generic_node(object.name,
                                                "host.png",
                                                "#{ui_lookup(:table => "host")}: #{object.name}") },
    "IsoDatastore"           => -> { generic_node(object.name, "isodatastore.png") },
    "IsoImage"               => -> { generic_node(object.name, "isoimage.png") },
    "ResourcePool"           => -> { generic_node(object.name, object.vapp ? "vapp.png" : "resource_pool.png") },

    "Lan"                    => -> { generic_node(object.name,
                                                "lan.png",
                                                _("Port Group: %{name}") % {:name => object.name}) },
    "LdapDomain"             => -> { generic_node(_("Domain: %{domain_name}") % {:domain_name => object.name},
                                                "ldap_domain.png",
                                                _("LDAP Domain: %{ldap_domain_name}") % {:ldap_domain_name => object.name}) },
    "LdapRegion"             => -> { generic_node(_("Region: %{region_name}") % {:region_name => object.name},
                                                "ldap_region.png",
                                                _("LDAP Region: %{ldap_region_name}") % {:ldap_region_name => object.name}) },
    "MiqAeClass"             => -> { node_with_display_name("ae_class.png") },
    "MiqAeInstance"          => -> { node_with_display_name("ae_instance.png") },
    "MiqAeMethod"            => -> { node_with_display_name("ae_method.png") },
    "MiqAeNamespace"         => -> { node_with_display_name("ae_namespace.png") },
    "MiqAlertSet"            => -> { generic_node(object.description, "miq_alert_profile.png") },
    "MiqReport"              => -> { generic_node(object.name, "report.png") },
    "MiqReportResult"        => -> { miq_report_node(object.last_run_on, object.name, object.status) },
    "MiqSchedule"            => -> { generic_node(object.name, "miq_schedule.png") },
    "MiqScsiLun"             => -> { generic_node(object.canonical_name,
                                                "lun.png",
                                                _("LUN: %{name}") % {:name => object.canonical_name}) },
    "MiqScsiTarget"          => -> { miq_scsi_target(object.iscsi_name, object.target) },
    "MiqServer"              => -> { miq_server_node },
    "MiqAlert"               => -> { generic_node(object.description, "miq_alert.png") },
    "MiqAction"              => -> { miq_action_node },
    "MiqEventDefinition"     => -> { generic_node(object.description, "event-#{object.name}.png") },
    "MiqGroup"               => -> { generic_node(object.name, "group.png") },
    # Following line has dynatree workaround, add class to allow clicking on bold portion of title.
    "MiqPolicy"              => -> { miq_policy_node },
    "MiqPolicySet"           => -> { generic_node(object.description, "policy_profile#{object.active? ? "" : "_inactive"}.png") },
    "MiqUserRole"            => -> { generic_node(object.name, "miq_user_role.png") },
    "OrchestrationTemplate"  => -> { orchestration_template_node },
    "PxeImage"               => -> { generic_node(object.name, object.default_for_windows ? "win32service.png" : "pxeimage.png") },
    "WindowsImage"           => -> { generic_node(object.name, "os-windows_generic.png") },
    "PxeImageType"           => -> { generic_node(object.name, "pxeimagetype.png") },
    "PxeServer"              => -> { generic_node(object.name, "pxeserver.png") },
    "ScanItemSet"            => -> { generic_node(object.name, "scan_item_set.png") },
    "Service"                => -> { generic_node(object.name, object.picture ? "/pictures/#{object.picture.basename}" : "service.png") },
    "ServiceResource"        => -> { generic_node(object.resource_name, object.resource_type == "VmOrTemplate" ? "vm.png" : "service_template.png") },
    "ServerRole"             => -> { server_role_node(object) },
    "ServiceTemplate"        => -> { service_template_node },
    "ServiceTemplateCatalog" => -> { service_template_catalog_node },
    "Snapshot"               => -> { snapshot_node },
    "Storage"                => -> { generic_node(object.name, "storage.png") },
    "Switch"                 => -> { generic_node(object.name,
                                                "switch.png",
                                                _("Switch: %{name}") % {:name => object.name}) },
    "User"                   => -> { generic_node(object.name, "user.png") },
    "MiqSearch"              => -> { generic_node(object.description,
                                                "filter.png",
                                                _("Filter: %{filter_description}") % {:filter_description => object.description}) },
    "MiqDialog"              => -> { generic_node(object.description, "miqdialog.png", object[0]) },
    "MiqRegion"              => -> { miq_region_node },
    "MiqWidget"              => -> { generic_node(object.title, "#{object.content_type}_widget.png", object.title) },
    "MiqWidgetSet"           => -> { generic_node(object.name, "dashboard.png", object.name) },
    "Tenant"                 => -> { generic_node(object.name, "#{object.tenant? ? "tenant" : "project"}.png") },
    "VmdbTable"              => -> { generic_node(object.name, "vmdbtableevm.png") },
    "VmdbIndex"              => -> { generic_node(object.name, "vmdbindex.png") },
    "VmOrTemplate"           => -> { vm_node(object) },
    "Zone"                   => -> { zone_node },
    "Hash"                   => -> { hash_node },
  }.freeze
  # rubocop:enable all

  def build
    # If this is a Decorator, then move grab it's `.object` since we will want
    # to lookup based on that.
    obj = object.kind_of?(Draper::Decorator) ? object.object : object

    # Find the proc for the class either based on it's class name, or it's
    # `base_class` (the top level of the inheritence tree)
    node_lambda =   BUILD_NODE_HASH[obj.class.name]
    node_lambda ||= BUILD_NODE_HASH[obj.class.base_class.to_s]

    # Execute the proc from the BUILD_NODE_HASH in the context of the instance
    instance_exec(&node_lambda) if node_lambda
    @node
  end

  private

  def get_rr_status_image(status)
    case status
    when 'error'    then 'report_result_error.png'
    when 'finished' then 'report_result_completed.png'
    when 'running'  then 'report_result_running.png'
    when 'queued'   then 'report_result_queued.png'
    else                 'report_result.png'
    end
  end

  def tooltip(tip)
    unless tip.blank?
      tip = tip.kind_of?(Proc) ? tip.call : _(tip)
      tip = ERB::Util.html_escape(URI.unescape(tip)) unless tip.html_safe?
      @node[:tooltip] = tip
    end
  end

  def node_icon(icon)
    if icon.start_with?("/")
      icon
    else
      ActionController::Base.helpers.image_path("100/#{icon}")
    end
  end

  def generic_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text ? URI.unescape(text) : text) unless text.html_safe?
    @node = {
      :key   => build_object_id,
      :title => text,
      :icon  => node_icon(image)
    }
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = options[:open_all].present? && options[:open_all] && options[:expand] != false
    @node[:hideCheckbox] = options[:hideCheckbox] if options[:hideCheckbox].present?
    tooltip(tip)
  end

  def normal_folder_node
    icon = options[:type] == :vandt ? "blue_folder.png" : "folder.png"
    generic_node(object.name, icon, _("Folder: %{folder_name}") % {:folder_name => object.name})
  end

  def guest_node(object)
    if object.device_type == "ethernet"
      generic_node(object.device_name, "pnic.png", _("Physical NIC: %{name}") % {:name => object.device_name})
    else
      generic_node(object.device_name,
                   "sa_#{object.controller_type.downcase}.png",
                   _("%{type} Storage Adapter: %{name}") % {:type => object.controller_type,
                                                            :name => object.device_name})
    end
  end

  def classification_node
    generic_node(object.description, 'folder', _("Category: %{description}") % {:description => object.description})
    @node[:cfmeNoClick] = true
    @node[:hideCheckbox] = true
  end

  def hash_node
    text = object[:text]
    text = text.kind_of?(Proc) ? text.call : _(text)

    # FIXME: expansion
    @node = {
      :key   => build_hash_id,
      :title => ERB::Util.html_escape(text)
    }
    @node[:icon] = node_icon("#{object[:image] || text}.png") if object[:image]
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if options[:open_all] && options[:expand] != false
    @node[:cfmeNoClick] = object[:cfmeNoClick] if object.key?(:cfmeNoClick)
    @node[:hideCheckbox] = true if object.key?(:hideCheckbox)
    @node[:select] = object[:select] if object.key?(:select)
    @node[:addClass] = object[:addClass] if object.key?(:addClass)
    @node[:checkable] = object[:checkable] if object.key?(:checkable)

    # FIXME: check the following
    # TODO: With dynatree, unless folders are open, we can't jump to a child node until it has been visible once
    # node[:expand] = false

    tooltip(object[:tip])
  end

  def node_with_display_name(image)
    text = object.display_name.blank? ? object.name : "#{object.display_name} (#{object.name})"
    if object.kind_of?(MiqAeNamespace) && object.domain?
      editable_domain = editable_domain?(object)
      enabled_domain  = object.enabled
      unless editable_domain && enabled_domain
        text = add_read_only_suffix(text, editable_domain, enabled_domain)
        return miq_ae_node(enabled_domain,
                           text,
                           image_for_node(object, image),
                           "#{tooltip_prefix_for_node(object)}: #{text}"
                          )
      end
    end
    generic_node(text, image_for_node(object, image), "#{tooltip_prefix_for_node(object)}: #{text}")
  end

  def miq_ae_node(enabled, text, image, tip)
    text = ERB::Util.html_escape(text) unless text.html_safe?
    @node = {
      :key   => build_object_id,
      :title => text,
      :icon  => node_icon(image)
    }
    @node[:addClass] = "strikethrough" unless enabled
    @node[:expand] = true if options[:open_all]  # Start with all nodes open
    tooltip(tip)
  end

  def configuration_profile_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text) unless text.html_safe?
    title = text.split('|').first
    @node = {
      :key   => build_object_id,
      :title => title,
      :icon  => node_icon(title == _("Unassigned Profiles Group") ? "folder.png" : image)
    }
    @node[:expand] = true if options[:open_all]  # Start with all nodes open
    tooltip(tip)
  end

  def vm_node(object)
    image = "currentstate-#{object.normalized_state.downcase}.png"
    unless object.template?
      tip = _("VM: %{name} (Click to view)") % {:name => object.name}
    end
    generic_node(object.name, image, tip)
  end

  def image_for_node(object, image)
    case object
    when MiqAeNamespace
      if object.domain?
        object.git_enabled? ? "ae_git_domain.png" : domain_png(object)
      else
        "ae_namespace.png"
      end
    else
      image
    end
  end

  def domain_png(object)
    return 'miq.png' if object.name == MiqAeDatastore::MANAGEIQ_DOMAIN
    object.top_level_namespace ? "vendor-#{object.top_level_namespace.downcase}.png" : "ae_domain.png"
  end

  def tooltip_prefix_for_node(object)
    case object
    when MiqAeNamespace
      object.domain? ? ui_lookup(:model => "MiqAeDomain") : ui_lookup(:model => object.class.to_s)
    else
      ui_lookup(:model => object.class.to_s)
    end
  end

  def custom_button_set_node
    text = if options[:type] == :sandt
             _("%{button_group_name} (Group)") % {:button_group_name => object.name.split("|").first}
           else
             object.name.split("|").first
           end
    image = object.set_data && object.set_data[:button_image] ? "custom-#{object.set_data[:button_image]}.png" : "folder.png"
    tip = if object.description
            _("Button Group: %{button_group_description}") % {:button_group_description => object.description}
          else
            object.name.split("|").first
          end
    generic_node(text, image, tip)
  end

  def ems_folder_node
    if object.kind_of?(Datacenter)
      generic_node(object.name,
                   "datacenter.png",
                   _("Datacenter: %{datacenter_name}") % {:datacenter_name => object.name})
    else # normal Folders
      normal_folder_node
    end
  end

  def miq_scsi_target(iscsi_name, target)
    name = if iscsi_name.blank?
             _("SCSI Target %{target}") % {:target => target}
           else
             _("SCSI Target %{target} (%{name})") % {:target => target, :name => iscsi_name}
           end
    generic_node(name, "target_scsi.png", _("Target: %{text}") % {:text => name})
  end

  def miq_server_node
    if options[:is_current]
      tip  = _("%{server}: %{server_name} [%{server_id}] (current)") %
             {:server => ui_lookup(:model => object.class.to_s), :server_name => object.name, :server_id => object.id}
      tip += " (#{object.status})" if options[:tree] == :roles_by_server_tree
      text = "<strong>#{ERB::Util.html_escape(tip)}</strong>".html_safe
    else
      tip  = "#{ui_lookup(:model => object.class.to_s)}: #{object.name} [#{object.id}]"
      tip += " (#{object.status})" if options[:tree] == :roles_by_server_tree
      text = tip
    end
    generic_node(text, 'miq_server.png', tip)
    @node[:expand] = true
    @node
  end

  def miq_action_node
    if options[:tree] != :action_tree
      if options[:tree] == :policy_profile_tree
        policy_id = parent_id.split('-')[2].split('_').first
        event_id  = parent_id.split('-').last
      else
        policy_id = parent_id.split('_')[2].split('-').last
        event_id  = parent_id.split('_').last.split('-').last
      end
      p  = MiqPolicy.find_by_id(ApplicationRecord.uncompress_id(policy_id))
      ev = MiqEventDefinition.find_by_id(ApplicationRecord.uncompress_id(event_id))
      image = p.action_result_for_event(object, ev) ? "check" : "x"
    else
      image = object.action_type == "default" ? "miq_action" : "miq_action_#{object.action_type}"
    end
    generic_node(object.description, "#{image}.png")
  end

  def miq_region_node
    generic_node(object.name, "miq_region.png", object[0])
    @node[:expand] = true
    @node
  end

  def service_template_node
    generic_node(object.name, object.picture ? "../../../pictures/#{object.picture.basename}" : "service_template.png")
    @node[:title] += " (%s)" % object.tenant.name unless object.tenant.ancestors.empty?
  end

  def service_template_catalog_node
    generic_node(object.name, "service_template_catalog.png")
    @node[:title] += " (%s)" % object.tenant.name if object.tenant.present? && object.tenant.ancestors.present?
  end

  def snapshot_node
    generic_node(object.name, 'snapshot.png', object.name)
    @node[:title] += _(' (Active)') if object.current?
  end

  def zone_node
    if options[:is_current]
      tip  = _("%{zone}: %{zone_description} (current)") %
             {:zone => ui_lookup(:model => object.class.to_s), :zone_description => object.description}
      text = "<strong>#{ERB::Util.html_escape(tip)}</strong>".html_safe
    else
      tip  = "#{ui_lookup(:model => object.class.to_s)}: #{object.description}"
      text = tip
    end
    generic_node(text, "zone.png", tip)
  end

  def policy_profile_text
    ["<strong>", ui_lookup(:model => object.towhat),
     " ", object.mode.titleize, ":</strong> ",
     ERB::Util.html_escape(object.description)].join('').html_safe
  end

  def miq_policy_node
    text  = options[:tree] == :policy_profile_tree ? policy_profile_text : object.description
    image = "miq_policy_#{object.towhat.downcase}#{object.active ? '' : '_inactive'}.png"
    generic_node(text, image)
  end

  def orchestration_template_node
    image_suffix = "_%s" % object.class.name.underscore.split("_").last.downcase
    image_suffix = "_vapp" if image_suffix == "_template"
    generic_node(object.name, "orchestration_template#{image_suffix}.png")
  end

  def format_parent_id
    (options[:full_ids] && !parent_id.blank?) ? "#{parent_id}_" : ''
  end

  def build_hash_id
    if object[:id] == "-Unassigned"
      "-Unassigned"
    else
      prefix = TreeBuilder.get_prefix_for_model("Hash")
      "#{format_parent_id}#{prefix}-#{object[:id]}"
    end
  end

  def build_object_id
    if object.id.nil?
      # FIXME: this makes problems in tests
      # to handle "Unassigned groups" node in automate buttons tree
      "-#{object.name.split('|').last}"
    else
      base_class = object.class.base_model.name           # i.e. Vm or MiqTemplate
      base_class = "Datacenter" if base_class == "EmsFolder" && object.kind_of?(Datacenter)
      base_class = "ManageIQ::Providers::Foreman::ConfigurationManager" if object.kind_of?(ManageIQ::Providers::Foreman::ConfigurationManager)
      base_class = "ManageIQ::Providers::AnsibleTower::ConfigurationManager" if object.kind_of?(ManageIQ::Providers::AnsibleTower::ConfigurationManager)
      prefix = TreeBuilder.get_prefix_for_model(base_class)
      cid = ApplicationRecord.compress_id(object.id)
      "#{format_parent_id}#{prefix}-#{cid}"
    end
  end

  def miq_report_node(last_run_on, name, status)
    status = status.downcase
    image = get_rr_status_image(status)
    if last_run_on.nil? && (status == "queued" || status == "running")
      expand = !!options[:open_all]

      @node = TreeNodeBuilder.generic_tree_node(
        build_object_id,
        _("Generating Report"),
        image,
        _("Generating Report for - %{report_name}") % {:report_name => name},
        :expand => expand
      )
    elsif last_run_on.nil? && status == "error"
      generic_node(_("Error Generating Report"), image,
        _("Error Generating Report for %{report_name}") % {:report_name => name})
    else
      text = format_timezone(last_run_on, Time.zone, 'gtl')
      generic_node(text, image)
    end
  end

  def assigned_server_role_node(object)
    @node = {
      :key   => build_object_id,
      :title => options[:tree] == :servers_by_role_tree ?
        "<strong>#{_('Server')}: #{object.name} [#{object.id}]</strong>" :
        "<strong>Role: #{object.server_role.description}</strong>"
    }

    if object.master_supported?
      priority = case object.priority
                 when 1
                   _("primary, ")
                 when 2
                   _("secondary, ")
                 else
                   ""
                 end
    end
    if object.active? && object.miq_server.started?
      @node[:icon] = ActionController::Base.helpers.image_path("100/on.png")
      @node[:title] += _(" (%{priority}active, PID=%{number})") % {:priority => priority, :number => object.miq_server.pid}
    else
      if object.miq_server.started?
        @node[:icon] = ActionController::Base.helpers.image_path("100/suspended.png")
        @node[:title] += _(" (%{priority}available, PID=%{number})") % {:priority => priority,
                                                                        :number   => object.miq_server.pid}
      else
        @node[:icon] = ActionController::Base.helpers.image_path("100/off.png")
        @node[:title] += _(" (%{priority}unavailable)") % {:priority => priority}
      end
      @node[:addClass] = "red" if object.priority == 1
    end
    if @options[:parent_kls] == "Zone" && object.server_role.regional_role?
      @node[:addClass] = "opacity"
    end
    @node
  end

  def server_role_node(object)
    status = "stopped"
    object.assigned_server_roles.where(:active => true).each do |asr| # Go thru all active assigned server roles
      next unless asr.miq_server.started? # Find a started server
      if @options[:parent_kls] == "MiqRegion" || # it's in the region
         (@options[:parent_kls] == "Zone" && asr.miq_server.my_zone == @options[:parent_name]) # it's in the zone
        status = "active"
        break
      end
    end
    @node = {
      :key    => build_object_id,
      :title  => _("Role: %{description} (%{status})") % {:description => object.description, :status => status},
      :icon   => ActionController::Base.helpers.image_path("100/role-#{object.name}.png"),
      :expand => true
    }
    tooltip(_("Role: %{description} (%{status})") % {:description => object.description, :status => status})
    @node
  end
end
