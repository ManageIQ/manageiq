class TreeBuilderAeCustomization < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:open_all => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("Service Dialog Import/Export"), t]
  end

  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, nil, nil)
  end
end
