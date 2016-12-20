class TreeBuilderReportReports < TreeBuilderReportReportsClass
  private

  def initialize(name, type, sandbox, build = true)
    @rpt_menu  = sandbox[:rpt_menu]
    @grp_title = sandbox[:grp_title]
    super(name, type, sandbox, build = true)
  end

  def tree_init_options(tree_name)
    {
      :leaf     => 'full_ids',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Reports"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, options)
    objects = []
    @rpt_menu.each_with_index do |r, i|
      objects.push(
        :id    => i.to_s,
        :text  => r[0],
        :image => (@grp_title == r[0] ? '100/blue_folder.png' : '100/folder.png'),
        :tip   => r[0]
      )
      # load next level of folders when building the tree
      @tree_state.x_tree(options[:tree])[:open_nodes].push("xx-#{i}")
    end
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    objects = []
    nodes = object[:full_id] ? object[:full_id].split('-') : object[:id].to_s.split('-')
    if nodes.length == 1 # && nodes.last.split('-').length <= 2 #|| nodes.length == 2
      @rpt_menu[nodes.last.to_i][1].each_with_index do |r, i|
        objects.push(
          :id    => "#{nodes.last.split('-').last}-#{i}",
          :text  => r[0],
          :image => (@grp_title == @rpt_menu[nodes.last.to_i][0] ? '100/blue_folder.png' : '100/folder.png'),
          :tip   => r[0]
        )
      end
    elsif nodes.length >= 2 # || (object[:full_id] && object[:full_id].split('_').length == 2)
      el1 = nodes.length == 2 ? nodes[0].split('_').first.to_i : nodes[1].split('_').first.to_i
      @rpt_menu[el1][1][nodes.last.to_i][1].each_with_index do |r|
        objects.push(MiqReport.find_by_name(r))
        # break after adding 1 report for a count_only,
        # don't need to go thru them all to determine if node has children
        break if count_only
      end
    end
    count_only_or_objects(count_only, objects)
  end
end
