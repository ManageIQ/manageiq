class TreeBuilderServersByRole < TreeBuilder
  has_kids_for ServerRole, [:x_get_tree_server_role_kids]

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
    count_only_or_objects(count_only, x_get_tree_server_roles)
  end

  def x_get_tree_server_roles
    ServerRole.all.sort_by(&:description).each_with_object([]) do |r, objects|
      next if @root.kind_of?(MiqRegion) && !r.regional_role? # Only regional roles under Region
      next unless (@root.kind_of?(Zone) && r.miq_servers.any? { |s| s.my_zone == @root.name }) ||
                  (@root.kind_of?(MiqRegion) && !r.miq_servers.empty?) # Skip if no assigned servers in this zone
      next if r.name == "database_owner"
      unless @sb[:diag_selected_id] # Set default selected record vars
        @sb[:diag_selected_model] = r.class.to_s
        @sb[:diag_selected_id] = r.id
      end
      objects.push(r)
    end
  end

  def x_get_tree_server_role_kids(parent, count_only)
    parent.assigned_server_roles.sort_by { |asr| asr.miq_server.name }.each_with_object([]) do |asr, kids|
      next if parent.kind_of?(Zone) && asr.miq_server.my_zone != parent.name
      kids.push(asr)
    end
  end
end
