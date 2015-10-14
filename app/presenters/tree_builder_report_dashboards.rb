class TreeBuilderReportDashboards < TreeBuilder
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
  def x_get_tree_roots(options)
    objects = []
    default_ws = MiqWidgetSet.find_by_name_and_read_only('default', true)
    text = "#{default_ws.description} (#{default_ws.name})"
    objects.push(:id => to_cid(default_ws.id), :text => text, :image => 'dashboard', :tip => text)
    objects.push(:id => 'g', :text => 'All Groups', :image => 'folder', :tip => 'All Groups')
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_custom_kids(object, options)
    assert_type(options[:type], :db)
    objects = []
    if object[:id].split('-').first == "g"
      objects = MiqGroup.all
      return options[:count_only] ? objects.count : objects.sort_by(&:name)
    end
    count_only_or_objects(options[:count_only], objects, :name)
  end

  def x_get_tree_g_kids(object, options)
    objects = []
    # dashboard nodes under each group
    widgetsets = MiqWidgetSet.find_all_by_owner_type_and_owner_id("MiqGroup", object.id)
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
      objects = copy_array(widgetsets)
    end
    options[:count_only] ? objects.count : objects.sort_by { |a| a.name.to_s.downcase }
  end
end
