class TreeBuilderContainersFilter < TreeBuilder
  private

  def tree_init_options(_)
    {
      :leaf     => "Container",
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "container_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_options)
    objects =
      [
        {:id          => "global",
         :text        => "Global Filters",
         :image       => "folder",
         :tip         => "Global Shared Filters",
         :cfmeNoClick => true}
      ]
    objects
  end

  def x_get_tree_custom_kids(object, options)
    case object[:id]
    when "global" # Global filters
      objects = MiqSearch.all(:conditions => ["(search_type=? or (search_type=? and (search_key is null
                                                or search_key<>?))) and db=?", "global", "default", "_hidden_",
                                              options[:leaf]]).sort_by { |a| a.description.downcase }
    end
    options[:count_only] ? objects.length : objects
  end
end
