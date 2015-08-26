class TreeBuilderAlert < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :leaf => 'MiqAlert'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "al_",
    )
  end

  def root_options
    [N_("All Alerts"), N_("All Alerts")]
  end
end
