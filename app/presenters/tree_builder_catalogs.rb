class TreeBuilderCatalogs < TreeBuilderCatalogsClass
  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :leaf => 'ServiceTemplateCatalog'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'stcat_',
      :autoload  => 'true',
    )
  end

  def x_get_tree_stc_kids(_object, count_only)
    count_only_or_objects(count_only, [], nil)
  end
end
