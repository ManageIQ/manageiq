class TreeBuilderReportSavedReports < TreeBuilderReportReportsClass
  private

  # Overwrites the x_build_node_dynatree method (which is just a wrapper around
  # `x_build_node`) to call `x_build_node` with a block for grabbing the kids
  # that will return a simple array if over 1000 kids exists.
  def x_build_node_dynatree(object, pid, options)
    x_build_node(object, pid, options) do |parents, id|
      tree_objects = x_get_tree_objects(object, options, false, parents)
      x_build_tree_with_limit(tree_objects, id, options)
    end
  end

  def x_build_tree_with_limit(tree_objects, id, tree_state)
    if tree_objects.count > 1000
      # Display a subtree with a single node saying the tree is too big to
      # load.  This is a cheaper solution than instanciating a dummy
      # TreeNodeBuilder just to use the generic_node method.
      [{ :key   => nil,
         :title => 'Tree to large to load!',
         :icon  => ActionController::Base.helpers.image_path('100/x.png'),
         :tooltip => 'Use table to the right to view reports'
      }]
    else
      tree_objects.map do |o|
        x_build_node(o, id, tree_state)
      end
    end
  end

  def tree_init_options(tree_name)
    {
      :full_ids => true,
      :leaf     => 'MiqReportResult'
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'savedreports_',
      :autoload  => true
    )
  end

  def root_options
    [t = _("All Saved Reports"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    folder_ids = {}
    u = User.current_user
    user_groups = u.admin_user? ? nil : u.miq_groups
    MiqReport.having_report_results(:miq_groups => user_groups, :select => [:id, :name]).each do |r|
      folder_ids[r.name] = to_cid(r.id.to_i)
    end
    objects = []
    folder_ids.sort.each_with_index do |p|
      objects.push(:id => p[1], :text => p[0], :image => 'report', :tip => p[0])
    end
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    scope = MiqReportResult.with_current_user_groups_and_report(from_cid(object[:id].split('-').last))
    count_only ? scope.size : scope.order("last_run_on DESC").to_a
  end
end
