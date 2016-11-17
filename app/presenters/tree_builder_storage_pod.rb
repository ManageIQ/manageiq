class TreeBuilderStoragePod < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:leaf => "Storage"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Datastore Clusters"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    items = EmsFolder.where(:type => 'StorageCluster')
    items.each do |item|
      objects.push(:id            => item[:id],
                   :tree          => "dsc_tree",
                   :text          => item[:name],
                   :image         => "folder",
                   :tip           => item[:description],
                   :load_children => true)
    end
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, type)
    objects = []
    dsc = EmsFolder.where(:id => object[:id])
    if(dsc.size > 0)
      objects = dsc.first.storages
    end
    count_only_or_objects(count_only, objects, "name")
  end
end
