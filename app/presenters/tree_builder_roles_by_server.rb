class TreeBuilderRolesByServer < TreeBuilder
  include TreeBuilderServerRolesCommon
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

  def x_get_tree_roots(_count_only, _options)
    x_get_tree_miq_servers
  end

  def x_get_tree_miq_servers
    @root.miq_servers.sort_by { |s| s.name.to_s }.each_with_object([]) do |server, objects|
      unless @sb[:diag_selected_id] # Set default selected record vars
        @sb[:diag_selected_model] = server.class.to_s
        @sb[:diag_selected_id] = server.id
      end
      objects.push(server)
    end
  end

  def x_get_tree_miq_server_kids(parent, _count_only)
    parent.assigned_server_roles.sort_by { |asr| asr.server_role.description }.each_with_object([]) do |asr, objects|
      next if parent.kind_of?(MiqRegion) && !asr.server_role.regional_role? # Only regional roles under Region
      next if asr.server_role.name == "database_owner"
      objects.push(asr)
    end
  end
end
