class TreeBuilderConfigurationManager < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:leaf => "ManageIQ::Providers::ConfigurationManager"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'pt_')
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    objects.push(:id => "fr",
                 :text => "Foreman Providers",
                 :image => "foreman_providers",
                 :tip => "Foreman Providers") if ApplicationHelper.role_allows(:feature => "provider_foreman_view",
                                                                               :any => true)
    objects.push(:id => "at",
                 :text => "Ansible Tower Providers",
                 :image => "ansible_tower_providers",
                 :tip => "Ansible Tower Providers") if ApplicationHelper.role_allows(:feature => "provider_foreman_view",
                                                                                     :any => true)
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_cmat_kids(object, count_only)
    count_only_or_objects(count_only,
                          "hostname")
  end

  def x_get_tree_cmf_kids(object, count_only)
    assigned_configuration_profile_objs =
      count_only_or_objects(count_only,
                            rbac_filtered_objects(ConfigurationProfile.where(:configuration_manager_id => object[:id]), :match_via_descendants => %w(ConfiguredSystem)),
                            "name")
    unassigned_configuration_profile_objs =
      fetch_unassigned_configuration_profile_objects(count_only, object[:id])

    assigned_configuration_profile_objs + unassigned_configuration_profile_objs
  end

  def fetch_unassigned_configuration_profile_objects(count_only, configuration_manager_id)
    unprovisioned_configured_systems = ConfiguredSystem.where(:configuration_profile_id => nil,
                                                              :configuration_manager_id => configuration_manager_id)
    unprovisioned_configured_systems_filtered = rbac_filtered_objects(unprovisioned_configured_systems,
                                                                      :match_via_descendants => ConfiguredSystem)
    if unprovisioned_configured_systems_filtered.count > 0
      unassigned_id = "#{configuration_manager_id}-unassigned"
      unassigned_configuration_profile =
        [ConfigurationProfile.new(:name                     => "Unassigned Profiles Group|#{unassigned_id}",
                                  :configuration_manager_id => configuration_manager_id)]
      unassigned_configuration_profile_objs = count_only_or_objects(count_only,
                                                                    unassigned_configuration_profile,
                                                                    nil)
    end

    if unassigned_configuration_profile_objs.nil?
      count_only ? unassigned_configuration_profile_objs = 0 : unassigned_configuration_profile_objs = []
    end
    unassigned_configuration_profile_objs
  end

  def x_get_tree_cpf_kids(object, count_only)
    count_only_or_objects(count_only,
                          rbac_filtered_objects(ConfiguredSystem.where(:configuration_profile_id => object[:id]), :match_via_descendants => ConfiguredSystem),
                          "hostname")
  end

  def x_get_tree_custom_kids(object_hash, count_only, _options)
    objects =
      case object_hash[:id]
        when "fr"  then rbac_filtered_objects(ManageIQ::Providers::Foreman::ConfigurationManager.order("lower(name)"), :match_via_descendants => %w(ConfiguredSystem))
        when "at"  then rbac_filtered_objects(ManageIQ::Providers::AnsibleTower::ConfigurationManager.order("lower(name)"))
      end
    count_only_or_objects(count_only, objects, "name")
  end
end
