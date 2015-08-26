class TreeBuilderPolicy < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "po_",
      :autoload  => true,
    )
  end

  def root_options
    [N_("All Policies"), N_("All Policies")]
  end
end
