class NavbarGenerator
  include Singleton

  class << self
    extend Forwardable

    delegate [:menu, :tab_features_by_id, :tab_features_by_name, :tab_name,
              :each_feature_title_with_subitems] => :instance
  end

  attr_reader :menu

  private

  def tab_features_by_id(tab_id)
    @id_to_section[tab_id].features
  end

  def tab_features_by_name(tab_name)
    @name_to_section[tab_name].features
  end

  def each_feature_title_with_subitems
    @menu.each { |section| yield section.name, section.features }
  end

  def tab_name(tab_id)
    @id_to_section[tab_id].name
  end

  MenuSection = Struct.new(:id, :name, :items)
  class MenuSection
    def features
      items.collect(&:feature).compact
    end
  end

  MenuItem = Struct.new(:id, :name, :feature, :rbac_feature, :href)

  def initialize
    load_default_items
  #  load_custom_items
  end

  def load_default_items
    @menu = [
      MenuSection.new(:vi, "Cloud Intelligence", [
        MenuItem.new('dashboard', _('Dashboard'),   'dashboard',  {:feature => 'dashboard_view'},            '/dashboard/'),
        MenuItem.new('report',    _('Reports'),     'miq_report', {:feature => 'miq_report', :any => true},  '/report/explorer'),
        # MenuItem.new('usage',     _('Usage'),     'usage',      {:feature => 'usage'},                     '/report/usage/'), #  / Hiding usage for now - release 5.2
        MenuItem.new('chargeback', _('Chargeback'), 'chargeback', {:feature => 'chargeback', :any => true}, '/chargeback/explorer'),
        MenuItem.new('timeline',   _('Timelines'),  'timeline',   {:feature => 'timeline'},                 '/dashboard/timeline/'),
        MenuItem.new('rss',        _('RSS'),        'rss',        {:feature => 'rss'},                      '/alert/')
      ]),
      MenuSection.new(:svc, "Services", [
        MenuItem.new('services',       _('My Services'), 'service',             {:feature => 'service', :any => true},             '/service/explorer'),
        MenuItem.new('catalogs',       _('Catalogs'),    'catalog',             {:feature => 'catalog', :any => true},             '/catalog/explorer'),
        MenuItem.new('vm_or_template', _('Workloads'),   'vm_explorer_accords', {:feature => 'vm_explorer_accords', :any => true}, '/vm_or_template/explorer'),
        MenuItem.new('miq_request_vm', _('Requests'),    'miq_request',         {:feature => 'miq_request_show_list'},             '/miq_request?typ=vm')
      ]),
      MenuSection.new(:clo, "Clouds",    [
        MenuItem.new('ems_cloud',         _('Providers'),          'ems_cloud',                 {:feature => 'ems_cloud_show_list'},                     '/ems_cloud'),
        MenuItem.new('availability_zone', _('Availability Zones'), 'availability_zone',         {:feature => 'availability_zone_show_list'},             '/availability_zone'),
        MenuItem.new('cloud_tenant',      _('Tenants'),            nil,                         {:feature => 'cloud_tenant_show_list'},                  '/cloud_tenant'),
        MenuItem.new('flavor',            _('Flavors'),            'flavor',                    {:feature => 'flavor_show_list'},                        '/flavor'),
        MenuItem.new('security_group',    _('Security Groups'),    'security_group',            {:feature => 'security_group_show_list'},                '/security_group'),
        MenuItem.new('vm_cloud',          _('Instances'),          'vm_cloud_explorer_accords', {:feature => 'vm_cloud_explorer_accords', :any => true}, '/vm_cloud/explorer')
      ]),
      MenuSection.new(:inf, "Infrastructure", [
        MenuItem.new('ems_infra',        _('Providers'),        'ems_infra',     {:feature => 'ems_infra_show_list'},     '/ems_infra'),
        MenuItem.new('ems_cluster',      _('Clusters'),         'ems_cluster',   {:feature => 'ems_cluster_show_list'},   '/ems_cluster'),
        MenuItem.new('host',             _('Hosts'),            'host',          {:feature => 'host_show_list'},          '/host'),
        MenuItem.new('vm_infra',         _('Virtual Machines'), 'vm_infra_explorer_accords',
                                                                 {:feature => 'vm_infra_explorer_accords', :any => true}, '/vm_infra/explorer'),
        MenuItem.new('resource_pool',    _('Resource Pools'),   'resource_pool', {:feature => 'resource_pool_show_list'}, '/resource_pool'),
        MenuItem.new('storage',          ui_lookup(:tables => 'storages'),
                                                                'storage',       {:feature => 'storage_show_list'},       '/storage'),
        MenuItem.new('repository',       _('Repositories'),     'repository',    {:feature => 'repository_show_list'},    '/repository'),
        MenuItem.new('pxe',              _('PXE'),              'pxe',           {:feature => 'pxe', :any => true},       '/pxe/explorer'),
        MenuItem.new('miq_request_host', _('Requests'),         nil,             {:feature => 'miq_request_show_list'},   "/miq_request?typ=host")
      ]),
      false ? #get_vmdb_config[:product][:storage] ? # FIXME
      MenuSection.new(:sto, "Storage",   [
        MenuItem.new('ontap_storage_system',  ui_lookup(:tables => 'ontap_storage_system'), 'ontap_storage_system',    {:feature => 'ontap_storage_system_show_list'}, '/ontap_storage_system'), 
        MenuItem.new('ontap_logical_disk',    ui_lookup(:tables => 'ontap_logical_disk'),   'ontap_logical_disk',      {:feature => 'ontap_logical_disk_show_list'},   '/ontap_logical_disk'),
        MenuItem.new('ontap_storage_volume',  ui_lookup(:tables => 'ontap_storage_volume'), 'ontap_storage_volume',    {:feature => 'ontap_storage_volume_show_list'}, '/ontap_storage_volume'),
        MenuItem.new('ontap_file_share',      ui_lookup(:tables => 'ontap_file_share'),     'ontap_file_share',        {:feature => 'ontap_file_share_show_list'},     '/ontap_file_share'),
        # MenuItem.new('cim_base_storage_extent', _('Base Extents'),                        'cim_base_storage_extent', {:feature => 'cim_base_storage_extent_show_list'}, '/cim_base_storage_extent'), # -if false
        MenuItem.new('storage_manager',         _('Storage Managers'),                      'storage_manager',         {:feature => 'storage_manager_show_list'}, '/storage_manager')
        # FIXME: removed feature snia_local_file_system
      ]) : nil,
      MenuSection.new(:con, "Control",   [
        MenuItem.new('miq_policy',        _('Explorer'),        'control_explorer',     {:feature => 'control_explorer_view'}, '/miq_policy/explorer'),
        MenuItem.new('miq_policy_rsop',   _('Simulation'),      'policy_simulation',    {:feature => 'policy_simulation'},     '/miq_policy/rsop'),
        MenuItem.new('miq_policy_export', _('Import / Export'), 'policy_import_export', {:feature => 'policy_import_export'},  '/miq_policy/export'),
        MenuItem.new('miq_policy_logs',   _('Log'),             'policy_log',           {:feature => 'policy_log'},            "/miq_policy/log")
      ]),
      MenuSection.new(:aut, "Automate",  [
        MenuItem.new('miq_ae_class',         _('Explorer'),        'miq_ae_class_explorer',      {:feature => 'miq_ae_domain_view'},            '/miq_ae_class/explorer'),
        MenuItem.new('miq_ae_tools',         _('Simulation'),      'miq_ae_class_simulation',    {:feature => 'miq_ae_class_simulation'},       '/miq_ae_tools/resolve'),
        MenuItem.new('miq_ae_customization', _('Customization'),   'miq_ae_class_custom_button', {:feature => 'miq_ae_customization_explorer'}, '/miq_ae_customization/explorer'),
        MenuItem.new('miq_ae_export',        _('Import / Export'), 'miq_ae_class_import_export', {:feature => 'miq_ae_class_import_export'},    '/miq_ae_tools/import_export'),
        MenuItem.new('miq_ae_logs',          _('Log'),             'miq_ae_class_log',           {:feature => 'miq_ae_class_log'},              '/miq_ae_tools/log'),
        MenuItem.new('miq_request_ae',       _('Requests'),        nil,                          {:feature => 'miq_request_show_list'},         "/miq_request?typ=ae")
      ]),
      MenuSection.new(:opt, "Optimize",  [
        MenuItem.new('miq_capacity_utilization', _('Utilization'), 'utilization', {:feature => 'utilization'}, '/miq_capacity'),
        MenuItem.new('miq_capacity_planning',    _('Planning'),    'planning',    {:feature => 'planning'},    '/miq_capacity/planning'),
        MenuItem.new('miq_capacity_bottlenecks', _('Bottlenecks'), 'bottlenecks', {:feature => 'bottlenecks'}, '/miq_capacity/bottlenecks')
      ]),
      MenuSection.new(:set, "Configure", [
        MenuItem.new('configuration', _('My Settings'),   'my_settings',  {:feature => 'my_settings', :any => true},  '/configuration/index?config_tab=ui'),
        MenuItem.new('my_tasks',      _('Tasks'),         'tasks',        {:feature => 'tasks', :any => true},        '/miq_proxy/index?jobs_tab=tasks'),
        MenuItem.new('ops',           _('Configuration'), 'ops_explorer', {:feature => 'ops_explorer', :any => true}, '/ops/explorer'),
        MenuItem.new('miq_proxy',     _('SmartProxies'),  'miq_proxy',    {:feature => 'miq_proxy_show_list'},        '/miq_proxy'),
        MenuItem.new('about',         _('About'),         'about',        {:feature => 'about'},                      '/support/index?support_tab=about')
      ])
    ].compact

    @id_to_section   = {}
    @name_to_section = {}
    @menu.each do |item|
      @id_to_section[item.id]     = item
      @name_to_section[item.name] = item
    end
  end
end
