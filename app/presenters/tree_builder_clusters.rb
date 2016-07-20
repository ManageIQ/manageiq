class TreeBuilderClusters < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, root = nil)
    @root = root
    @data = EmsCluster.get_perf_collection_object_list
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => false,
     :add_root => false,
     :lazy     => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => 'cluster_',
                  :checkboxes                  => true,
                  :onselect                    => "miqOnCheckCUFilters",
                  :onclick                     => false,
                  :check_url                   => "/ops/cu_collection_field_changed/",
                  :open_close_all_on_dbl_click => true)
  end

  def root_options
    []
  end

  def non_cluster_selected
    i = 0
    @root[:non_cl_hosts].each do |h|
      i += 1 if h[:capture]
    end
    if @root[:non_cl_hosts].size == i
      true
    elsif @root[:non_cl_hosts].empty?
      false
    else
      'unsure'
    end
  end

  def x_get_tree_roots(count_only = false, _options)
    nodes = @root[:clusters].map do |node|
      { :id       => node[:id].to_s,
        :text     => node[:name],
        :image    => 'cluster',
        :tip      => node[:name],
        :select   => node[:capture] != 'unsure' && node[:capture],
        :addClass => node[:capture] == 'unsure' ? 'dynatree-partsel' : '',
        :children => @data[node[:id]][:ho_enabled] + @data[node[:id]][:ho_disabled]
      }
    end
    if @root[:non_cl_hosts].present?
      node = {:id       => "NonCluster",
              :text     => _("Non-clustered Hosts"),
              :image    => 'host',
              :tip      => _("Non-clustered Hosts"),
              :select   => non_cluster_selected,
              :children => @root[:non_cl_hosts]
      }
      if non_cluster_selected == 'unsure'
        node[:addClass] = 'dynatree-partsel'
        node[:select] = true
      end
      nodes.push(node)
    end
    count_only_or_objects(count_only, nodes)
  end

  def x_get_tree_hash_kids(parent, count_only)
    hosts = parent[:children]
    nodes = hosts.map do |node|
      if @data[parent[:id].to_i]
        value = @data[parent[:id].to_i][:ho_disabled].include? node
      end
      {:id       => "#{parent[:id]}_#{node[:id]}",
       :text     => node[:name],
       :tip      => _("Host: %{name}") % {:name => node[:name]},
       :image    => 'host',
       :select   => node.kind_of?(Hash) ? node[:capture] : !value,
       :children => []}
    end
    count_only_or_objects(count_only, nodes)
  end
end
