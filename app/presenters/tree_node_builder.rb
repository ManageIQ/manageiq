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

  def build
    case object
    when AvailabilityZone     then generic_node(object.name,
                                                "availability_zone.png",
                                                _("Availability Zone: %{name}") % {:name => object.name})
    when ConfigurationScript then generic_node(object.name,
                                               "configuration_script.png",
                                               "Ansible Job Template: #{object.name}")
    when ExtManagementSystem  then
      # TODO: This should really leverage .base_model on an EMS
      prefix_model =
        case object
        when EmsCloud then "EmsCloud"
        when EmsInfra then "EmsInfra"
        else               "ExtManagementSystem"
        end

      generic_node(object.name, "vendor-#{object.image_name}.png", "#{ui_lookup(:model => prefix_model)}: #{object.name}")
    when ChargebackRate       then generic_node(object.description, "chargeback_rate.png")
    when Condition            then generic_node(object.description, "miq_condition.png")
    when ConfigurationProfile then configuration_profile_node(object.name, "configuration_profile.png",
                                                              _("Configuration Profile: %{name}") % {:name => object.name})
    when ConfiguredSystem     then generic_node(object.hostname,
                                                "configured_system.png",
                                                _("Configured System: %{hostname}") % {:hostname => object.hostname})
    when Container            then generic_node(object.name, "container.png")
    when CustomButton         then generic_node(object.name,
                                                object.options && object.options[:button_image] ? "custom-#{object.options[:button_image]}.png" : "leaf.gif",
                                                _("Button: %{button_description}") % {:button_description => object.description})
    when CustomButtonSet      then custom_button_set_node
    when CustomizationTemplate then generic_node(object.name, "customizationtemplate.png")
    when Dialog               then generic_node(object.label, "dialog.png")
    when DialogTab            then generic_node(object.label, "dialog_tab.png")
    when DialogGroup          then generic_node(object.label, "dialog_group.png")
    when DialogField          then generic_node(object.label, "dialog_field.png")
    when EmsFolder            then ems_folder_node
    when EmsCluster           then generic_node(object.name, "cluster.png", "#{ui_lookup(:table => "ems_cluster")}: #{object.name}")
    when Host                 then generic_node(object.name, "host.png",    "#{ui_lookup(:table => "host")}: #{object.name}")
    when IsoDatastore         then generic_node(object.name, "isodatastore.png")
    when IsoImage             then generic_node(object.name, "isoimage.png")
    when ResourcePool         then generic_node(object.name, object.vapp ? "vapp.png" : "resource_pool.png")
    when Vm                   then generic_node(object.name, "currentstate-#{object.normalized_state.downcase}.png")
    when LdapDomain           then generic_node(_("Domain: %{domain_name}") % {:domain_name => object.name},
                                                "ldap_domain.png",
                                                _("LDAP Domain: %{ldap_domain_name}") % {:ldap_domain_name => object.name})
    when LdapRegion           then generic_node(_("Region: %{region_name}") % {:region_name => object.name},
                                                "ldap_region.png",
                                                _("LDAP Region: %{ldap_region_name}") % {:ldap_region_name => object.name})
    when MiqAeClass           then node_with_display_name("ae_class.png")
    when MiqAeInstance        then node_with_display_name("ae_instance.png")
    when MiqAeMethod          then node_with_display_name("ae_method.png")
    when MiqAeNamespace       then node_with_display_name("ae_namespace.png")
    when MiqAlertSet          then generic_node(object.description, "miq_alert_profile.png")
    when MiqReport            then generic_node(object.name, "report.png")
    when MiqReportResult      then miq_report_node(format_timezone(object.last_run_on, Time.zone, 'gtl'),
                                                   get_rr_status_image(object), object.name, object.status.downcase)
    when MiqSchedule          then generic_node(object.name, "miq_schedule.png")
    when MiqServer            then miq_server_node
    when MiqTemplate          then generic_node(object.name, "currentstate-#{object.normalized_state.downcase}.png")
    when MiqAlert             then generic_node(object.description, "miq_alert.png")
    when MiqAction            then miq_action_node
    when MiqEventDefinition   then generic_node(object.description, "event-#{object.name}.png")
    when MiqGroup             then generic_node(object.name, "group.png")
    # Following line has dynatree workaround, add class to allow clicking on bold portion of title.
    when MiqPolicy            then miq_policy_node
    when MiqPolicySet         then generic_node(object.description, "policy_profile#{object.active? ? "" : "_inactive"}.png")
    when MiqUserRole          then generic_node(object.name, "miq_user_role.png")
    when OrchestrationTemplateCfn then generic_node(object.name, "orchestration_template_cfn.png")
    when OrchestrationTemplateHot then generic_node(object.name, "orchestration_template_hot.png")
    when OrchestrationTemplateAzure then generic_node(object.name, "orchestration_template_azure.png")
    when PxeImage             then generic_node(object.name, object.default_for_windows ? "win32service.png" : "pxeimage.png")
    when WindowsImage         then generic_node(object.name, "os-windows_generic.png")
    when PxeImageType         then generic_node(object.name, "pxeimagetype.png")
    when PxeServer            then generic_node(object.name, "pxeserver.png")
    when ScanItemSet          then generic_node(object.name, "scan_item_set.png")
    when Service              then generic_node(object.name, object.picture ? "../../../pictures/#{object.picture.basename}" : "service.png")
    when ServiceResource      then generic_node(object.resource_name, object.resource_type == "VmOrTemplate" ? "vm.png" : "service_template.png")
    when ServiceTemplate      then service_template_node
    when ServiceTemplateCatalog then service_template_catalog_node
    when Storage              then generic_node(object.name, "storage.png")
    when User                 then generic_node(object.name, "user.png")
    when MiqSearch            then generic_node(object.description,
                                                "filter.png",
                                                _("Filter: %{filter_description}") % {:filter_description => object.description})
    when MiqDialog            then generic_node(object.description, "miqdialog.png", object[0])
    when MiqRegion            then miq_region_node
    when MiqWidget            then generic_node(object.title, "#{object.content_type}_widget.png", object.title)
    when MiqWidgetSet         then generic_node(object.name, "dashboard.png", object.name)
    when Tenant               then generic_node(object.name,  "#{object.tenant? ? "tenant" : "project"}.png")
    when VmdbTableEvm         then generic_node(object.name, "vmdbtableevm.png")
    when VmdbIndex            then generic_node(object.name, "vmdbindex.png")
    when Zone                 then zone_node
    when Hash                 then hash_node
    end
    @node
  end

  private

  def get_rr_status_image(rec)
    case rec.status.downcase
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
    ActionController::Base.helpers.image_path("100/#{icon}")
  end

  def generic_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text ? URI.unescape(text) : text) unless text.html_safe?
    @node = {
      :key   => build_object_id,
      :title => text,
      :icon  => node_icon(image)
    }
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if options[:open_all] && options[:expand] != false
    tooltip(tip)
  end

  def normal_folder_node
    icon = options[:type] == :vandt ? "blue_folder.png" : "folder.png"
    generic_node(object.name, icon, _("Folder: %{folder_name}") % {:folder_name => object.name})
  end

  def hash_node
    text = object[:text]
    text = text.kind_of?(Proc) ? text.call : _(text)

    # FIXME: expansion
    @node = {
      :key   => build_hash_id,
      :icon  => node_icon("#{object[:image] || text}.png"),
      :title => ERB::Util.html_escape(text),
    }
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if options[:open_all] && options[:expand] != false
    @node[:cfmeNoClick] = object[:cfmeNoClick] if object.key?(:cfmeNoClick)

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
    @node[:addClass] = "product-strikethru-node" unless enabled
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

  def image_for_node(object, image)
    case object
    when MiqAeNamespace
      object.domain? ? "ae_domain.png" : "ae_namespace.png"
    else
      image
    end
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

  def miq_server_node
    if options[:is_current]
      tip  = _("%{server}: %{server_name} [%{server_id}] (current)") %
             {:server => ui_lookup(:model => object.class.to_s), :server_name => object.name, :server_id => object.id}
      text = "<b class='dynatree-title'>#{ERB::Util.html_escape(tip)}</b>".html_safe
    else
      tip  = "#{ui_lookup(:model => object.class.to_s)}: #{object.name} [#{object.id}]"
      text = tip
    end
    generic_node(text, 'miq_server.png', tip)
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

  def zone_node
    if options[:is_current]
      tip  = _("%{zone}: %{zone_description} (current)") %
             {:zone => ui_lookup(:model => object.class.to_s), :zone_description => object.description}
      text = "<b class='dynatree-title'>#{ERB::Util.html_escape(tip)}</b>".html_safe
    else
      tip  = "#{ui_lookup(:model => object.class.to_s)}: #{object.description}"
      text = tip
    end
    generic_node(text, "zone.png", tip)
  end

  def policy_profile_text
    ["<b class='dynatree-title'>", ui_lookup(:model => object.towhat),
     " ", object.mode.titleize, ":</b> ",
     ERB::Util.html_escape(object.description)].join('').html_safe
  end

  def miq_policy_node
    text  = options[:tree] == :policy_profile_tree ? policy_profile_text : object.description
    image = "miq_policy_#{object.towhat.downcase}#{object.active ? '' : '_inactive'}.png"
    generic_node(text, image)
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

  def miq_report_node(text, image, name, status)
    if text == "" && (status == "queued" || status == "running")
      expand = false
      expand = true if options[:open_all]

      @node = TreeNodeBuilder.generic_tree_node(
        build_object_id,
        _("Generating Report"),
        image,
        _("Generating Report for - %{report_name}") % {:report_name => name},
        :expand => expand
      )
    else
      generic_node(text, image)
    end
  end
end
