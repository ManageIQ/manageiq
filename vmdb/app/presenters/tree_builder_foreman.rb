class TreeBuilderForeman  < TreeBuilder
  attr_reader :tree_nodes

  private

  def tree_init_options(_tree_name)
    {:leaf => "ConfigurationManagerForeman"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'pt_')
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], ConfigurationManagerForeman.all, "name")
  end

  def x_get_tree_cmf_kids(object, options)
    assigned_configuration_profile_objs =
      count_only_or_objects(options[:count_only],
                            ConfigurationProfile.where(:configuration_manager_id => object[:id]),
                            "name")
    unassigned_configuration_profile_objs =
      fetch_unassigned_configuration_profile_objects(options[:count_only], object[:id])

    assigned_configuration_profile_objs + unassigned_configuration_profile_objs
  end

  def fetch_unassigned_configuration_profile_objects(count_only, configuration_manager_id)
    unprovisioned_configured_systems = ConfiguredSystem.where(:configuration_profile_id => nil,
                                                              :configuration_manager_id => configuration_manager_id)
    if unprovisioned_configured_systems.count > 0
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

  def x_get_tree_cpf_kids(object, options)
    count_only_or_objects(options[:count_only],
                          ConfiguredSystem.where(:configuration_profile_id => object[:id]),
                          "hostname")
  end
end
