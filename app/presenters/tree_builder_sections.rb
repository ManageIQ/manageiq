class TreeBuilderSections < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, data, controller_name, current_tenant)
    @data = data
    @controller_name = controller_name
    @current_tenant = current_tenant
    @sandbox = sandbox
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :add_root => false, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => 'all_sections_',
                  :checkboxes                  => true,
                  :onclick                     => false,
                  :three_checks                => true,
                  :onselect                    => "miqOnCheckSections",
                  :enable_tree_images          => false,
                  :check_url                   => "/#{@controller_name}/sections_field_changed/",
                  :open_close_all_on_dbl_click => true)
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    nodes = []
    group = nil
    @data.master_list.each_slice(3) do |section, _records, _fields|
      if group.blank? || section[:group] != group
        group = section[:group]
        nodes.push({:id       => "group_#{section[:group]}",
                    :text     => section[:group] == "Categories" ? "#{@current_tenant} Tags" : section[:group],
                    :tip      => section[:group],
                    :image    => false,
                    :select   => true,
                    :children => [section]})
      else
        nodes.last[:children].push(section)
      end
    end
    nodes.each do |node|
      i = 0 # number of checked kids
      node[:children].each do |kid|
        if @data.include[kid[:name]][:checked]
          i += 1
        end
      end
      if i == 0
        node[:select] = false
      elsif i < node[:children].size
        node[:select] = false
        node[:addClass] = 'dynatree-partsel'
      end
    end
    count_only_or_objects(count_only, nodes)
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = parent[:children].map do |kid|
      {:id           =>  "group_#{kid[:group]}:#{kid[:name]}",
       :text         => kid[:header],
       :tip          => kid[:header],
       :image        => false,
       :select       => @data.include[kid[:name]][:checked],
       :children     => []
      }
    end
    count_only_or_objects(count_only, nodes)
  end

end