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
    items = EmsFolder.where(:type => 'StorageCluster')
    if count_only
      items.size
    else
      items.map do |item|
        {
          :id            => item[:id],
          :tree          => "dsc_tree",
          :text          => item[:name],
          :image         => "100/folder.png",
          :tip           => item[:description],
          :load_children => true
        }
      end
    end
  end

  def x_get_tree_custom_kids(object, count_only, type)
    objects = EmsFolder.find_by(:id => object[:id]).try!(:storages)
    count_only_or_objects(count_only, objects || [], "name")
  end
end
