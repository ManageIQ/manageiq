class TreeBuilderAlertProfile < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :leaf => 'MiqAlertSet'}
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
end
