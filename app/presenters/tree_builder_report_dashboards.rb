class TreeBuilderReportDashboards < TreeBuilder
  has_kids_for MiqGroup, [:x_get_tree_g_kids]

  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Dashboards',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'dashboards_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = []
    default_ws = MiqWidgetSet.find_by(:name => 'default', :read_only => true)
    text = "#{default_ws.description} (#{default_ws.name})"
    objects.push(:id => to_cid(default_ws.id), :text => text, :image => 'dashboard', :tip => text)
    objects.push(:id => 'g', :text => _('All Groups'), :image => 'folder', :tip => _('All Groups'))
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_custom_kids(object, count_only, options)
    assert_type(options[:type], :db)
    objects = []
    if object[:id].split('-').first == "g"
      objects = rbac_filtered_objects(MiqGroup.non_tenant_groups)
      return count_only ? objects.count : objects.sort_by(&:name)
    end
    count_only_or_objects(count_only, objects, :name)
  end

  def x_get_tree_g_kids(object, count_only)
    objects = []
    # dashboard nodes under each group
    widgetsets = MiqWidgetSet.where(:owner_type => "MiqGroup", :owner_id => object.id)
    # if dashboard sequence was saved, build tree using that, else sort by name and build the tree
    if object.settings && object.settings[:dashboard_order]
      object.settings[:dashboard_order].each do |ws_id|
        widgetsets.each do |ws|
          if ws_id == ws.id
            objects.push(ws)
          end
        end
      end
    else
      objects = copy_array(widgetsets.to_a)
    end
    count_only ? objects.count : objects.sort_by { |a| a.name.to_s.downcase }
  end
end
