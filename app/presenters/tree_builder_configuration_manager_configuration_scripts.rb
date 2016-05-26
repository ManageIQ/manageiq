class TreeBuilderConfigurationManagerConfigurationScripts < TreeBuilder
  has_kids_for ManageIQ::Providers::AnsibleTower::ConfigurationManager, [:x_get_tree_cmat_kids]
  attr_reader :tree_nodes

  private

  def tree_init_options(_tree_name)
    {:leaf => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true, :id_prefix => 'cf_')
  end

  def root_options
    [t = _("All Ansible Tower Job Templates"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only,
                          rbac_filtered_objects(ManageIQ::Providers::AnsibleTower::ConfigurationManager.order("lower(name)"), :match_via_descendants => ConfigurationScript), "name")
  end

  def x_get_tree_cmat_kids(object, count_only)
    count_only_or_objects(count_only,
                          rbac_filtered_objects(ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript.where(:manager_id => object.id)), "name")
  end
end
