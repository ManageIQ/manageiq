class TreeBuilderPxeImageTypes < TreeBuilder

  private

  def tree_init_options(tree_name)
   {:full_ids => true, :leaf => "PxeImageType"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "pit_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], PxeImageType.all, "name")
  end
end
