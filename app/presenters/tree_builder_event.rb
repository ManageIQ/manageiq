class TreeBuilderEvent < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ev_",
    )
  end

  def root_options
    [N_("All Events"), N_("All Events")]
  end
end
