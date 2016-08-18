class TreeBuilderInfraNetworking < TreeBuilder
  has_kids_for ManageIQ::Providers::Vmware::InfraManager, [:x_get_tree_provider_kids]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]
  has_kids_for Host, [:x_get_tree_host_kids]
  has_kids_for Switch, [:x_get_tree_switch_kids]

  private

  def tree_init_options(_tree_name)
    {:leaf     => "Switch"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'nt_', :autoload => true)
  end

  def root_options
    [t = _("All Distributed Switches"), t]
  end

  def x_get_tree_roots(count_only, _options)
    objects = Rbac.filtered(ManageIQ::Providers::Vmware::InfraManager.order("lower(name)"))
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_provider_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(EmsCluster.where(:ems_id => object[:id])),
                          "name")
  end

  def x_get_tree_cluster_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(object.hosts),
                          "name")
  end

  def x_get_tree_host_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(object.switches.where(:shared =>'true')).sort,
                          "name")
  end

  def x_get_tree_switch_kids(object, count_only)
    count_only_or_objects(count_only,
                          object.lans.sort,
                          "name")
  end
end
