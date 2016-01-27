class TreeBuilderConfigurationManagerConfiguredSystems < TreeBuilder
  attr_reader :tree_nodes

  private

  def tree_init_options(_tree_name)
    {:leaf     => "ConfiguredSystem",
     :open_all => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'cs_')
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    objects.push(:id => "csf",  :text => "Foreman Configured Systems",   :image => "foreman_cs",  :tip => "Foreman Configured Systems ")   if ApplicationHelper.role_allows(:feature => "provider_foreman_view", :any => true)
    objects.push(:id => "csa", text: "Ansible Tower Configured Systems",  :image => "ansible_tower_cs",  :tip => "Ansible Tower Configured Systems")  if ApplicationHelper.role_allows(:feature => "provider_foreman_view", :any => true)
    return count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_csf_kids(_count_only, _options)
    [
      {:id          => "csf_global",
       :text        => "Global Filters",
       :image       => "folder",
       :tip         => "Global Shared Filters",
       :cfmeNoClick => true,
       :expand      => true
      },
      {:id          => "csf_my",
       :text        => "My Filters",
       :image       => "folder",
       :tip         => "My Personal Filters",
       :cfmeNoClick => true,
       :expand      => true
      }
    ]
  end

  def x_get_tree_csa_kids(_count_only, _options)
    [
      {:id          => "csa_global",
       :text        => "Global Filters",
       :image       => "folder",
       :tip         => "Global Shared Filters",
       :cfmeNoClick => true,
       :expand      => true
      },
      {:id          => "csa_my",
       :text        => "My Filters",
       :image       => "folder",
       :tip         => "My Personal Filters",
       :cfmeNoClick => true,
       :expand      => true
      }
    ]
  end

  def x_get_tree_custom_kids(object, count_only, options)
    objects = x_get_search_results(object, options[:leaf])
    count_only ? objects.length : objects
  end

  def x_get_search_results(object, leaf)
    case object[:id]
    when "global" # Global filters
      x_get_global_filter_search_results(leaf)
    when "my"     # My filters
      x_get_my_filter_search_results(leaf)
    end
  end

  def x_get_global_filter_search_results(leaf)
    MiqSearch.where(:db => leaf).visible_to_all.sort_by { |a| a.description.downcase }
  end

  def x_get_my_filter_search_results(leaf)
    MiqSearch.where(:db => leaf, :search_type => "user", :search_key => User.current_user.userid)
      .sort_by { |a| a.description.downcase }
  end
end
