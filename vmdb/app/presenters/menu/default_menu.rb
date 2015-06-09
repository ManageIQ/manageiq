module Menu
  class DefaultMenu
    class << self
      def cloud_inteligence_menu_section
        Menu::Section.new(:vi, "Cloud Intelligence", [
          Menu::Item.new('dashboard',  N_('Dashboard'),  'dashboard',  {:feature => 'dashboard_view'},           '/dashboard/'),
          Menu::Item.new('report',     N_('Reports'),    'miq_report', {:feature => 'miq_report', :any => true}, '/report/explorer'),
          # Menu::Item.new('usage',    N_('Usage'),      'usage',      {:feature => 'usage'},                    '/report/usage/'), #  / Hiding usage for now - release 5.2
          Menu::Item.new('chargeback', N_('Chargeback'), 'chargeback', {:feature => 'chargeback', :any => true}, '/chargeback/explorer'),
          Menu::Item.new('timeline',   N_('Timelines'),  'timeline',   {:feature => 'timeline'},                 '/dashboard/timeline/'),
          Menu::Item.new('rss',        N_('RSS'),        'rss',        {:feature => 'rss'},                      '/alert/')
        ])
      end

      def services_menu_section
        Menu::Section.new(:svc, "Services", [
          Menu::Item.new('services',       N_('My Services'), 'service',             {:feature => 'service', :any => true},             '/service/explorer'),
          Menu::Item.new('catalogs',       N_('Catalogs'),    'catalog',             {:feature => 'catalog', :any => true},             '/catalog/explorer'),
          Menu::Item.new('vm_or_template', N_('Workloads'),   'vm_explorer_accords', {:feature => 'vm_explorer_accords', :any => true}, '/vm_or_template/explorer'),
          Menu::Item.new('miq_request_vm', N_('Requests'),    'miq_request',         {:feature => 'miq_request_show_list'},             '/miq_request?typ=vm')
        ])
      end

      def clouds_menu_section
        Menu::Section.new(:clo, "Clouds", [
          Menu::Item.new('ems_cloud',           N_('Providers'),           'ems_cloud',                 {:feature => 'ems_cloud_show_list'},                     '/ems_cloud'),
          Menu::Item.new('availability_zone',   N_('Availability Zones'),  'availability_zone',         {:feature => 'availability_zone_show_list'},             '/availability_zone'),
          Menu::Item.new('cloud_tenant',        N_('Tenants'),             'cloud_tenant',              {:feature => 'cloud_tenant_show_list'},                  '/cloud_tenant'),
          Menu::Item.new('flavor',              N_('Flavors'),             'flavor',                    {:feature => 'flavor_show_list'},                        '/flavor'),
          Menu::Item.new('security_group',      N_('Security Groups'),     'security_group',            {:feature => 'security_group_show_list'},                '/security_group'),
          Menu::Item.new('vm_cloud',            N_('Instances'),           'vm_cloud_explorer', {:feature => 'vm_cloud_explorer_accords', :any => true}, '/vm_cloud/explorer'),
          Menu::Item.new('orchestration_stack', N_('Stacks'),              'orchestration_stack',       {:feature => 'orchestration_stack_show_list'},           '/orchestration_stack')
        ])
      end

      def infrastructure_menu_section
        hosts_name    = hybrid_name(EmsCluster, N_("Hosts"),    N_("Nodes"),            N_("Hosts / Nodes"))
        clusters_name = hybrid_name(Host,       N_("Clusters"), N_("Deployment Roles"), N_("Clusters / Deployment Roles"))

        Menu::Section.new(:inf, "Infrastructure", [
          Menu::Item.new('ems_infra',        N_('Providers'),        'ems_infra',     {:feature => 'ems_infra_show_list'},     '/ems_infra'),
          Menu::Item.new('ems_cluster',      clusters_name,          'ems_cluster',   {:feature => 'ems_cluster_show_list'},   '/ems_cluster'),
          Menu::Item.new('host',             hosts_name,             'host',          {:feature => 'host_show_list'},          '/host'),
          Menu::Item.new('vm_infra',         N_('Virtual Machines'), 'vm_infra_explorer',
                                                                                      {:feature => 'vm_infra_explorer_accords', :any => true},
                                                                                                                               '/vm_infra/explorer'),
          Menu::Item.new('resource_pool',    N_('Resource Pools'),   'resource_pool', {:feature => 'resource_pool_show_list'}, '/resource_pool'),
          Menu::Item.new('storage',          ui_lookup(:tables => 'storages'),
                                                                     'storage',       {:feature => 'storage_show_list'},       '/storage'),
          Menu::Item.new('repository',       N_('Repositories'),     'repository',    {:feature => 'repository_show_list'},    '/repository'),
          Menu::Item.new('pxe',              N_('PXE'),              'pxe',           {:feature => 'pxe', :any => true},       '/pxe/explorer'),
          Menu::Item.new('miq_request_host', N_('Requests'),         nil,             {:feature => 'miq_request_show_list'},   '/miq_request?typ=host'),
          Menu::Item.new('provider_foreman', N_('Configuration Management'), 'provider_foreman_explorer',
                         {:feature => 'provider_foreman_explorer', :any => true}, '/provider_foreman/explorer')
        ])
      end

      def hybrid_name(klass, name1, name2, name3)
        lambda do
          case klass.node_types
          when :non_openstack then name1
          when :openstack     then name2
          else                     name3
          end
        end
      end
      private :hybrid_name

      def container_menu_section
        Menu::Section.new(:cnt, "Containers", [
          Menu::Item.new('ems_container',     ui_lookup(:tables => 'ems_container'),     'ems_container',     {:feature => 'ems_container_show_list'},     '/ems_container'),
          Menu::Item.new('container_project', ui_lookup(:tables => 'container_project'), 'container_project', {:feature => 'container_project_show_list'}, '/container_project'),
          Menu::Item.new('container_node',    ui_lookup(:tables => 'container_node'),    'container_node',    {:feature => 'container_node_show_list'},    '/container_node'),
          Menu::Item.new('container_group',   ui_lookup(:tables => 'container_group'),   'container_group',   {:feature => 'container_group_show_list'},   '/container_group'),
          Menu::Item.new('container_route',   ui_lookup(:tables => 'container_route'),   'container_route',   {:feature => 'container_route_show_list'},   '/container_route'),
          Menu::Item.new('container_replicator', ui_lookup(:tables => 'container_replicator'),   'container_replicator',   {:feature => 'container_replicator_show_list'},   '/container_replicator'),
          Menu::Item.new('container_service', ui_lookup(:tables => 'container_service'), 'container_service', {:feature => 'container_service_show_list'}, '/container_service'),
          Menu::Item.new('container',         ui_lookup(:tables => 'container'),         'containers',        {:feature => 'containers', :any => true},     '/container/explorer')
        ])
      end

      def storage_menu_section
        Menu::Section.new(:sto, "Storage", [
          Menu::Item.new('ontap_storage_system', ui_lookup(:tables => 'ontap_storage_system'), 'ontap_storage_system', {:feature => 'ontap_storage_system_show_list'}, '/ontap_storage_system'),
          Menu::Item.new('ontap_logical_disk',   ui_lookup(:tables => 'ontap_logical_disk'),   'ontap_logical_disk',   {:feature => 'ontap_logical_disk_show_list'},   '/ontap_logical_disk'),
          Menu::Item.new('ontap_storage_volume', ui_lookup(:tables => 'ontap_storage_volume'), 'ontap_storage_volume', {:feature => 'ontap_storage_volume_show_list'}, '/ontap_storage_volume'),
          Menu::Item.new('ontap_file_share',     ui_lookup(:tables => 'ontap_file_share'),     'ontap_file_share',     {:feature => 'ontap_file_share_show_list'},     '/ontap_file_share'),
          Menu::Item.new('storage_manager',      N_('Storage Managers'),                       'storage_manager',      {:feature => 'storage_manager_show_list'}, '/storage_manager')
        ])
      end

      def control_menu_section
        Menu::Section.new(:con, "Control", [
          Menu::Item.new('miq_policy',        N_('Explorer'),        'control_explorer',     {:feature => 'control_explorer_view'}, '/miq_policy/explorer'),
          Menu::Item.new('miq_policy_rsop',   N_('Simulation'),      'policy_simulation',    {:feature => 'policy_simulation'},     '/miq_policy/rsop'),
          Menu::Item.new('miq_policy_export', N_('Import / Export'), 'policy_import_export', {:feature => 'policy_import_export'},  '/miq_policy/export'),
          Menu::Item.new('miq_policy_logs',   N_('Log'),             'policy_log',           {:feature => 'policy_log'},            "/miq_policy/log")
        ])
      end

      def automate_menu_section
        Menu::Section.new(:aut, "Automate", [
          Menu::Item.new('miq_ae_class',         N_('Explorer'),        'miq_ae_class_explorer',         {:feature => 'miq_ae_domain_view'},            '/miq_ae_class/explorer'),
          Menu::Item.new('miq_ae_tools',         N_('Simulation'),      'miq_ae_class_simulation',       {:feature => 'miq_ae_class_simulation'},       '/miq_ae_tools/resolve'),
          Menu::Item.new('miq_ae_customization', N_('Customization'),   'miq_ae_customization_explorer', {:feature => 'miq_ae_customization_explorer'}, '/miq_ae_customization/explorer'),
          Menu::Item.new('miq_ae_export',        N_('Import / Export'), 'miq_ae_class_import_export',    {:feature => 'miq_ae_class_import_export'},    '/miq_ae_tools/import_export'),
          Menu::Item.new('miq_ae_logs',          N_('Log'),             'miq_ae_class_log',              {:feature => 'miq_ae_class_log'},              '/miq_ae_tools/log'),
          Menu::Item.new('miq_request_ae',       N_('Requests'),        nil,                             {:feature => 'miq_request_show_list'},         "/miq_request?typ=ae")
        ])
      end

      def optimize_menu_section
        Menu::Section.new(:opt, "Optimize", [
          Menu::Item.new('miq_capacity_utilization', N_('Utilization'), 'utilization', {:feature => 'utilization'}, '/miq_capacity'),
          Menu::Item.new('miq_capacity_planning',    N_('Planning'),    'planning',    {:feature => 'planning'},    '/miq_capacity/planning'),
          Menu::Item.new('miq_capacity_bottlenecks', N_('Bottlenecks'), 'bottlenecks', {:feature => 'bottlenecks'}, '/miq_capacity/bottlenecks')
        ])
      end

      def configuration_menu_section
        Menu::Section.new(:set, "Configure", [
          Menu::Item.new('configuration', _('My Settings'),   'my_settings',  {:feature => 'my_settings', :any => true},  '/configuration/index?config_tab=ui'),
          Menu::Item.new('my_tasks',      _('Tasks'),         'tasks',        {:feature => 'tasks', :any => true},        '/miq_task/index?jobs_tab=tasks'),
          Menu::Item.new('ops',           _('Configuration'), 'ops_explorer', {:feature => 'ops_explorer', :any => true}, '/ops/explorer'),
          Menu::Item.new('about',         _('About'),         'about',        {:feature => 'about'},                      '/support/index?support_tab=about')
        ])
      end

      def default_menu
        storage_enabled = VMDB::Config.new("vmdb").config[:product][:storage]
        containers_enabled = VMDB::Config.new("vmdb").config[:product][:containers]

        [cloud_inteligence_menu_section, services_menu_section, clouds_menu_section, infrastructure_menu_section, containers_enabled ? container_menu_section : nil,
         storage_enabled ? storage_menu_section : nil, control_menu_section, automate_menu_section,
         optimize_menu_section, configuration_menu_section].compact
      end
    end
  end
end
