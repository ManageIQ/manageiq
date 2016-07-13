class TreeBuilderRolesByServer < TreeBuilder
  has_kids_for MiqServer, [:x_get_tree_miq_server_kids]

  def initialize(name, type, sandbox, build = true, parent = nil)
    @root = parent
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {
      :add_root => false,
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

  def root_options
    []
  end

  def x_get_tree_roots(count_only = false, _options)
    count_only_or_objects(count_only, x_get_tree_miq_servers)
  end

  def x_get_tree_miq_servers
    objects = []
    @root.miq_servers.sort_by { |s| s.name.to_s }.each do |s|
      unless @sb[:diag_selected_id] # Set default selected record vars
        @sb[:diag_selected_model] = s.class.to_s
        @sb[:diag_selected_id] = s.id
      end
      objects.push(s)
    end
    objects
  end

  def x_get_tree_miq_server_kids(parent, _count_only)
    objects = []
    parent.assigned_server_roles.sort_by { |asr| asr.server_role.description }.each do |asr|
      next if parent.kind_of?(MiqRegion) && !asr.server_role.regional_role? # Only regional roles under Region
      next if asr.server_role.name == "database_owner"
      objects.push(asr)
    end
    objects
  end
end
