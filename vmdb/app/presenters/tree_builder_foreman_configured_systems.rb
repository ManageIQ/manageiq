class TreeBuilderForemanConfiguredSystems  < TreeBuilder
  attr_reader :tree_nodes

  private

  def tree_init_options(_tree_name)
    {:leaf     => "ConfiguredSystem",
     :open_all => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'csft_')
  end

  def x_get_tree_roots(_options)
    objects =
        [
          {:id          => "global",
           :text        => "Global Filters",
           :image       => "folder",
           :tip         => "Global Shared Filters",
           :cfmeNoClick => true,
           :expand      => true
          },
          {:id          => "my",
           :text        => "My Filters",
           :image       => "folder",
           :tip         => "My Personal Filters",
           :cfmeNoClick => true,
           :expand      => true
          }
        ]
    objects
  end

  def x_get_tree_custom_kids(object, options)
    objects = x_get_search_results(object, options)
    options[:count_only] ? objects.length : objects
  end

  def x_get_search_results(object, options)
    case object[:id]
    when "global" # Global filters
      objects = x_get_global_filter_search_results(options)
    when "my"     # My filters
      objects = x_get_my_filter_seacrh_results(options)
    end
    objects
  end

  def x_get_global_filter_search_results(options)
    MiqSearch.all(:conditions => ["(search_type=? or (search_type=? and (search_key is null or search_key<>?))) and
      db=?", "global", "default", "_hidden_", options[:leaf]]).sort_by { |a| a.description.downcase }
  end

  def x_get_my_filter_seacrh_results(options)
    MiqSearch.all(:conditions => ["search_type=? and search_key=? and db=?",
                                  "user",
                                  User.current_user.userid,
                                  options[:leaf]]).sort_by { |a| a.description.downcase }
  end
end
