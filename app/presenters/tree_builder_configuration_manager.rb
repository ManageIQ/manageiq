class TreeBuilderConfigurationManager < TreeBuilder
  has_kids_for ManageIQ::Providers::Foreman::ConfigurationManager, [:x_get_tree_cmf_kids]
  has_kids_for ManageIQ::Providers::AnsibleTower::ConfigurationManager, [:x_get_tree_cmat_kids]
  has_kids_for ManageIQ::Providers::ConfigurationManager::InventoryRootGroup, [:x_get_tree_igf_kids]
  has_kids_for ConfigurationProfile, [:x_get_tree_cpf_kids]

  private

  def tree_init_options(_tree_name)
    {:leaf     => "ManageIQ::Providers::ConfigurationManager"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Configuration Manager Providers"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    objects.push(:id            => "fr",
                 :tree          => "fr_tree",
                 :text          => _("%{name} Providers") % {:name => ui_lookup(:ui_title => 'foreman')},
                 :image         => "100/folder.png",
                 :tip           => _("%{name} Providers") % {:name => ui_lookup(:ui_title => 'foreman')},
                 :load_children => true)
    objects.push(:id            => "at",
                 :tree          => "at_tree",
                 :text          => _("Ansible Tower Providers"),
                 :image         => "100/folder.png",
                 :tip           => _("Ansible Tower Providers"),
                 :load_children => true)
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_cmat_kids(object, count_only)
    count_only_or_objects_filtered(count_only,
                                   ManageIQ::Providers::ConfigurationManager::InventoryGroup.where(:ems_id => object[:id]),
                                   "name", :match_via_descendants => ConfiguredSystem)
  end

  def x_get_tree_cmf_kids(object, count_only)
    assigned_configuration_profile_objs =
      count_only_or_objects_filtered(count_only,
                                     ConfigurationProfile.where(:manager_id => object[:id]),
                                     "name", :match_via_descendants => ConfiguredSystem)
    unassigned_configuration_profile_objs =
      fetch_unassigned_configuration_profile_objects(count_only, object[:id])

    assigned_configuration_profile_objs + unassigned_configuration_profile_objs
  end

  # Note: a lot of logic / queries to determine if should display menu item
  def fetch_unassigned_configuration_profile_objects(count_only, configuration_manager_id)
    unprovisioned_configured_systems = ConfiguredSystem.where(:configuration_profile_id => nil,
                                                              :manager_id               => configuration_manager_id)
    unprovisioned_configured_systems_filtered = Rbac.filtered(unprovisioned_configured_systems,
                                                              :match_via_descendants => ConfiguredSystem)
    if unprovisioned_configured_systems_filtered.count > 0
      unassigned_id = "#{configuration_manager_id}-unassigned"
      unassigned_configuration_profile =
        [ConfigurationProfile.new(:name       => "Unassigned Profiles Group|#{unassigned_id}",
                                  :manager_id => configuration_manager_id)]
    end
    count_only_or_objects(count_only, unassigned_configuration_profile || [])
  end

  def x_get_tree_cpf_kids(object, count_only)
    count_only_or_objects_filtered(count_only,
                                   ConfiguredSystem.where(:configuration_profile_id => object[:id],
                                                          :manager_id               => object[:manager_id]),
                                   "hostname", :match_via_descendants => ConfiguredSystem)
  end

  def x_get_tree_igf_kids(object, count_only)
    count_only_or_objects_filtered(count_only,
                                   ConfiguredSystem.where(:inventory_root_group_id=> object[:id]),
                                   "hostname", :match_via_descendants => ConfiguredSystem)
  end

  def x_get_tree_custom_kids(object_hash, count_only, _options)
    objects =
      case object_hash[:id]
      when "fr" then ManageIQ::Providers::Foreman::ConfigurationManager
      when "at" then ManageIQ::Providers::AnsibleTower::ConfigurationManager
      end
    count_only_or_objects_filtered(count_only, objects, "name", :match_via_descendants => ConfiguredSystem)
  end
end
