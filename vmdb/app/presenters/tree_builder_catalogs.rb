class TreeBuilderCatalogs < TreeBuilderCatalogsClass
  private

  def tree_init_options(tree_name)
    {:full_ids => true, :leaf => 'ServiceTemplateCatalog'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'stcat_',
      :autoload  => 'true',
    )
  end

  def x_get_tree_stc_kids(object, options)
    count_only_or_objects(options[:count_only], [], nil)
  end
end
