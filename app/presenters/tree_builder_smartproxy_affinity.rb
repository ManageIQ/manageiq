class TreeBuilderSmartproxyAffinity < TreeBuilder
  def initialize(name, type, sandbox, zone)
    super(name, type, sandbox)
    @zone = zone
  end

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

  # level 0 - root
  def root_options
    [t = N_("TODO"), t]
  end

  # level 1 - compliance & control
  def x_get_tree_roots(options)
    objects = []
    count_only_or_objects(options[:count_only], objects)
  end

end
