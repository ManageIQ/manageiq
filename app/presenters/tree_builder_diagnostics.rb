class TreeBuilderDiagnostics < TreeBuilder
  def initialize(name, type, sandbox, build = true, parent = nil)
    @root = parent
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:add_root => false,
     :expand   => true,
     :lazy     => false,
     :open_all => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload  => false,
                  :click_url => "/ops/diagnostics_tree_select/",
                  :onclick   => "miqOnClickServerRoles")
  end

  def x_build_single_node(object, pid, options)
    options[:parent_kls]  = @sb[:parent_kls] if @sb && @sb[:parent_kls]
    options[:parent_name] = @sb[:parent_name] if @sb && @sb[:parent_name]
    super(object, pid, options)
  end

  def root_options
    []
  end
end
