class TreeBuilderAlertProfile < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ap_",
      :autoload  => true,
    )
  end

  def root_options
    [N_("All Alert Profiles"), N_("All Alert Profiles")]
  end

  def x_get_tree_roots(options)
    open_nodes = @tree_state.x_tree(options[:tree])[:open_nodes]

    objects = []
    MiqAlert.base_tables.sort_by { |a| ui_lookup(:model => a) }.each do |db|
      objects << {:id => db, :text => "#{ui_lookup(:model => db)} Alert Profiles", :image => db.underscore.downcase, :tip => "#{ui_lookup(:model => db)} Alert Profiles"}

      # Set alert profile folder nodes to open so we pre-load all children
      n = "xx-#{db}"
      open_nodes << n unless open_nodes.include?(n)
    end

    count_only_or_objects(options[:count_only], objects)
  end

  def x_get_tree_ap_kids(parent, options)
    count_only_or_objects(options[:count_only],
                          parent.miq_alerts,
                          :description)
  end
end
