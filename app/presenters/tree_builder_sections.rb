class TreeBuilderSections < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build, data, controller_name, current_tenant)
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
    locals.merge!(:checkboxes   => true,
                  :three_checks => true,
                  :onselect     => "miqOnCheckSections",
                  :check_url    => "/#{@controller_name}/sections_field_changed/")
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
        nodes.push(:id          => "group_#{section[:group]}",
                   :text        => section[:group] == "Categories" ? "#{@current_tenant} Tags" : section[:group],
                   :tip         => section[:group],
                   :image       => false,
                   :select      => true,
                   :cfmeNoClick => true,
                   :children    => [section])
      else
        nodes.last[:children].push(section)
      end
    end
    nodes.each do |node|
      checked = node[:children].count { |kid| @data.include[kid[:name]][:checked] } # number of checked kids
      if checked == 0
        node[:select] = false
      elsif checked < node[:children].size
        node[:select] = 'undefined'
      else
        node[:select] = true
      end
    end
    count_only_or_objects(count_only, nodes)
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = parent[:children].map do |kid|
      {:id          => "group_#{kid[:group]}:#{kid[:name]}",
       :text        => kid[:header],
       :tip         => kid[:header],
       :image       => false,
       :select      => @data.include[kid[:name]][:checked],
       :cfmeNoClick => true,
       :children    => []
      }
    end
    count_only_or_objects(count_only, nodes)
  end
end
