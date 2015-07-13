class TreeBuilderAeCustomization  < TreeBuilder
  private

  def tree_init_options(tree_name)
    {:open_all => true }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], nil, nil)
  end

end
