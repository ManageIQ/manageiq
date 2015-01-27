module Menu
  class DefaultMenu
    class << self
      def cloud_inteligence_menu_section
        Menu::Section.new(:vi, "Cloud Intelligence", [
          Menu::Item.new('dashboard',  _('Dashboard'),  'dashboard',  {:feature => 'dashboard_view'},           '/dashboard/'),
          Menu::Item.new('report',     _('Reports'),    'miq_report', {:feature => 'miq_report', :any => true}, '/report/explorer'),
          # Menu::Item.new('usage',    _('Usage'),      'usage',      {:feature => 'usage'},                    '/report/usage/'), #  / Hiding usage for now - release 5.2
          Menu::Item.new('chargeback', _('Chargeback'), 'chargeback', {:feature => 'chargeback', :any => true}, '/chargeback/explorer'),
          Menu::Item.new('timeline',   _('Timelines'),  'timeline',   {:feature => 'timeline'},                 '/dashboard/timeline/'),
          Menu::Item.new('rss',        _('RSS'),        'rss',        {:feature => 'rss'},                      '/alert/')
        ])
      end

      def services_menu_section
        Menu::Section.new(:svc, "Services", [
          Menu::Item.new('services',       _('My Services'), 'service',             {:feature => 'service', :any => true},             '/service/explorer'),
          Menu::Item.new('catalogs',       _('Catalogs'),    'catalog',             {:feature => 'catalog', :any => true},             '/catalog/explorer'),
          Menu::Item.new('vm_or_template', _('Workloads'),   'vm_explorer_accords', {:feature => 'vm_explorer_accords', :any => true}, '/vm_or_template/explorer'),
          Menu::Item.new('miq_request_vm', _('Requests'),    'miq_request',         {:feature => 'miq_request_show_list'},             '/miq_request?typ=vm')
        ])
      end

      def clouds_menu_section
        Menu::Section.new(:clo, "Clouds", [
          Menu::Item.new('ems_cloud',         _('Providers'),           'ems_cloud',                 {:feature => 'ems_cloud_show_list'},                     '/ems_cloud'),
          Menu::Item.new('availability_zone', _('Availability Zones'),  'availability_zone',         {:feature => 'availability_zone_show_list'},             '/availability_zone'),
          Menu::Item.new('cloud_tenant',      _('Tenants'),             nil,                         {:feature => 'cloud_tenant_show_list'},                  '/cloud_tenant'),
          Menu::Item.new('flavor',            _('Flavors'),             'flavor',                    {:feature => 'flavor_show_list'},                        '/flavor'),
          Menu::Item.new('security_group',    _('Security Groups'),     'security_group',            {:feature => 'security_group_show_list'},                '/security_group'),
          Menu::Item.new('vm_cloud',          _('Instances'),           'vm_cloud_explorer_accords', {:feature => 'vm_cloud_explorer_accords', :any => true}, '/vm_cloud/explorer'),
          Menu::Item.new('orchestration_stack', _('Stacks'),'orchestration_stack',       {:feature => 'orchestration_stack_show_list'},             '/orchestration_stack')
        ])
      end

      def infrastructure_menu_section
        Menu::Section.new(:inf, "Infrastructure", [
          Menu::Item.new('ems_infra',        _('Providers'),        'ems_infra',     {:feature => 'ems_infra_show_list'},     '/ems_infra'),
          Menu::Item.new('ems_cluster',      _('Clusters'),         'ems_cluster',   {:feature => 'ems_cluster_show_list'},   '/ems_cluster'),
          Menu::Item.new('host',             _('Hosts'),            'host',          {:feature => 'host_show_list'},          '/host'),
          Menu::Item.new('vm_infra',         _('Virtual Machines'), 'vm_infra_explorer_accords',
                                                                                     {:feature => 'vm_infra_explorer_accords', :any => true},
                                                                                                                              '/vm_infra/explorer'),
          Menu::Item.new('resource_pool',    _('Resource Pools'),   'resource_pool', {:feature => 'resource_pool_show_list'}, '/resource_pool'),
          Menu::Item.new('storage',          ui_lookup(:tables => 'storages'),
                                                                    'storage',       {:feature => 'storage_show_list'},       '/storage'),
          Menu::Item.new('repository',       _('Repositories'),     'repository',    {:feature => 'repository_show_list'},    '/repository'),
          Menu::Item.new('pxe',              _('PXE'),              'pxe',           {:feature => 'pxe', :any => true},       '/pxe/explorer'),
          Menu::Item.new('miq_request_host', _('Requests'),         nil,             {:feature => 'miq_request_show_list'},   '/miq_request?typ=host')
        ])
      end

      def storage_menu_section
        Menu::Section.new(:sto, "Storage", [
          Menu::Item.new('ontap_storage_system', ui_lookup(:tables => 'ontap_storage_system'), 'ontap_storage_system', {:feature => 'ontap_storage_system_show_list'}, '/ontap_storage_system'),
          Menu::Item.new('ontap_logical_disk',   ui_lookup(:tables => 'ontap_logical_disk'),   'ontap_logical_disk',   {:feature => 'ontap_logical_disk_show_list'},   '/ontap_logical_disk'),
          Menu::Item.new('ontap_storage_volume', ui_lookup(:tables => 'ontap_storage_volume'), 'ontap_storage_volume', {:feature => 'ontap_storage_volume_show_list'}, '/ontap_storage_volume'),
          Menu::Item.new('ontap_file_share',     ui_lookup(:tables => 'ontap_file_share'),     'ontap_file_share',     {:feature => 'ontap_file_share_show_list'},     '/ontap_file_share'),
          Menu::Item.new('storage_manager',      _('Storage Managers'),                        'storage_manager',      {:feature => 'storage_manager_show_list'}, '/storage_manager')
        ])
      end

      def control_menu_section
        Menu::Section.new(:con, "Control", [
          Menu::Item.new('miq_policy',        _('Explorer'),        'control_explorer',     {:feature => 'control_explorer_view'}, '/miq_policy/explorer'),
          Menu::Item.new('miq_policy_rsop',   _('Simulation'),      'policy_simulation',    {:feature => 'policy_simulation'},     '/miq_policy/rsop'),
          Menu::Item.new('miq_policy_export', _('Import / Export'), 'policy_import_export', {:feature => 'policy_import_export'},  '/miq_policy/export'),
          Menu::Item.new('miq_policy_logs',   _('Log'),             'policy_log',           {:feature => 'policy_log'},            "/miq_policy/log")
        ])
      end

      def automate_menu_section
        Menu::Section.new(:aut, "Automate", [
          Menu::Item.new('miq_ae_class',         _('Explorer'),        'miq_ae_class_explorer',      {:feature => 'miq_ae_domain_view'},            '/miq_ae_class/explorer'),
          Menu::Item.new('miq_ae_tools',         _('Simulation'),      'miq_ae_class_simulation',    {:feature => 'miq_ae_class_simulation'},       '/miq_ae_tools/resolve'),
          Menu::Item.new('miq_ae_customization', _('Customization'),   'miq_ae_class_custom_button', {:feature => 'miq_ae_customization_explorer'}, '/miq_ae_customization/explorer'),
          Menu::Item.new('miq_ae_export',        _('Import / Export'), 'miq_ae_class_import_export', {:feature => 'miq_ae_class_import_export'},    '/miq_ae_tools/import_export'),
          Menu::Item.new('miq_ae_logs',          _('Log'),             'miq_ae_class_log',           {:feature => 'miq_ae_class_log'},              '/miq_ae_tools/log'),
          Menu::Item.new('miq_request_ae',       _('Requests'),        nil,                          {:feature => 'miq_request_show_list'},         "/miq_request?typ=ae")
        ])
      end

      def optimize_menu_section
        Menu::Section.new(:opt, "Optimize", [
          Menu::Item.new('miq_capacity_utilization', _('Utilization'), 'utilization', {:feature => 'utilization'}, '/miq_capacity'),
          Menu::Item.new('miq_capacity_planning',    _('Planning'),    'planning',    {:feature => 'planning'},    '/miq_capacity/planning'),
          Menu::Item.new('miq_capacity_bottlenecks', _('Bottlenecks'), 'bottlenecks', {:feature => 'bottlenecks'}, '/miq_capacity/bottlenecks')
        ])
      end

      def configuration_menu_section
        Menu::Section.new(:set, "Configure", [
          Menu::Item.new('configuration', _('My Settings'),   'my_settings',  {:feature => 'my_settings', :any => true},  '/configuration/index?config_tab=ui'),
          Menu::Item.new('my_tasks',      _('Tasks'),         'tasks',        {:feature => 'tasks', :any => true},        '/miq_proxy/index?jobs_tab=tasks'),
          Menu::Item.new('ops',           _('Configuration'), 'ops_explorer', {:feature => 'ops_explorer', :any => true}, '/ops/explorer'),
          Menu::Item.new('miq_proxy',     _('SmartProxies'),  'miq_proxy',    {:feature => 'miq_proxy_show_list'},        '/miq_proxy'),
          Menu::Item.new('about',         _('About'),         'about',        {:feature => 'about'},                      '/support/index?support_tab=about')
        ])
      end

      def default_menu
        storage_enabled = VMDB::Config.new("vmdb").config[:product][:storage]

        [cloud_inteligence_menu_section, services_menu_section, clouds_menu_section, infrastructure_menu_section,
         storage_enabled ? storage_menu_section : nil, control_menu_section, automate_menu_section,
         optimize_menu_section, configuration_menu_section].compact
      end
    end
  end
end
