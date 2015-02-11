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
    count_only_or_objects(options[:count_only],
                          ConfigurationProfile.where(:configuration_manager_id => object[:id]),
                          "name")
  end

  def x_get_tree_cpf_kids(object, options)
    count_only_or_objects(options[:count_only],
                          ConfiguredSystem.where(:configuration_profile_id => object[:id]),
                          "hostname")
  end
end
