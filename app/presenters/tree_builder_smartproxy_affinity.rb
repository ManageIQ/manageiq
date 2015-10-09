class TreeBuilderSmartproxyAffinity < TreeBuilder
  def initialize(name, type, sandbox, zone)
    super(name, type, sandbox)
    @zone = zone
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true,
     :add_root => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :autoload  => true,
    )
  end

  # level 0 - root
  def root_options
    [t = N_("TODO"), t]
  end

  # level 1 - compliance & control
  def x_get_tree_roots(options)
    objects = []
    objects << {:title=>"bar"}
    count_only_or_objects(options[:count_only], objects)
  end

  def build_smartproxy_affinity_node(zone, server, node_type)
    affinities = server.send("vm_scan_#{node_type}_affinity").collect(&:id)
    {
      :key      => "#{server.id}__#{node_type}",
      :icon     => "#{node_type}.png",
      :title    => Dictionary.gettext(node_type.camelcase, :type => :model, :notfound => :titleize).pluralize,
      :children => zone.send(node_type.pluralize).sort_by(&:name).collect do |node|
        {
          :key    => "#{server.id}__#{node_type}_#{node.id}",
          :icon   => "#{node_type}.png",
          :title  => node.name,
          :select => affinities.include?(node.id)
        }
      end
    }
  end

  # TODO remove
  def build_smartproxy_affinity_tree(zone)
    zone.miq_servers.select(&:is_a_proxy?).sort_by { |s| [s.name, s.id] }.collect do |s|
      title = "#{Dictionary.gettext('MiqServer', :type => :model, :notfound => :titleize)}: #{s.name} [#{s.id}]"
      title = "<b class='cfme-bold-node'>#{title} (current)</title>".html_safe if @sb[:my_server_id] == s.id
      {
        :key      => s.id.to_s,
        :icon     => 'evm_server.png',
        :title    => title,
        :expand   => true,
        :children => [build_smartproxy_affinity_node(zone, s, 'host'),
                      build_smartproxy_affinity_node(zone, s, 'storage')]
      }
    end
  end
end
