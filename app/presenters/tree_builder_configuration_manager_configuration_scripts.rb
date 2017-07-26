class TreeBuilderConfigurationManagerConfigurationScripts < TreeBuilder
  has_kids_for ManageIQ::Providers::AnsibleTower::ConfigurationManager, [:x_get_tree_cmat_kids]
  attr_reader :tree_nodes

  private

  def tree_init_options(_tree_name)
    {:leaf => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Ansible Tower Job Templates"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    templates = Rbac.filtered(ManageIQ::Providers::AnsibleTower::ConfigurationManager.order("lower(name)"),
                              :match_via_descendants => ConfigurationScript)

    templates.each do |temp|
      objects.push(temp)
    end

    objects.push(:id          => "global",
                 :text        => _("Global Filters"),
                 :image       => "folder",
                 :tip         => _("Global Shared Filters"),
                 :cfmeNoClick => true)
    objects.push(:id          => "my",
                 :text        => _("My Filters"),
                 :image       => "folder",
                 :tip         => _("My Personal Filters"),
                 :cfmeNoClick => true)
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_cmat_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript.where(:manager_id => object.id)), "name")
  end

  def x_get_tree_custom_kids(object, count_only, options)
    objects = MiqSearch.where(:db => options[:leaf]).filters_by_type(object[:id])
    count_only_or_objects(count_only, objects, 'description')
  end
end
