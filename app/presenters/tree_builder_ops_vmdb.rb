class TreeBuilderOpsVmdb < TreeBuilderOps
  has_kids_for VmdbTableEvm, [:x_get_tree_vmdb_table_kids]

  private

  def tree_init_options(_tree_name)
    {
      :open_all => false,
      :leaf     => "VmdbTable",
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("VMDB"), t, '100/miq_database.png']
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = Rbac.filtered(VmdbDatabase.my_database.evm_tables).to_a
    # storing table names and their id in hash so they can be used to build links on summary screen in top 5 boxes
    @sb[:vmdb_tables] = {}
    objects.each do |o|
      @sb[:vmdb_tables][o.name] = o.id
    end
    count_only_or_objects(count_only, objects, "name")
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
    rec = VmdbTableEvm.find_by_id(from_cid(object[:id].split("|").last.split('-').last))
    indexes = []
    rec.vmdb_indexes.each do |ind|
      indexes.push(ind) if ind.vmdb_table.type == "VmdbTableEvm"
    end
    count_only_or_objects(count_only, indexes, "name")
  end

  def x_get_tree_vmdb_table_kids(object, count_only)
    if count_only
      object.vmdb_indexes.count
    else
      # load this node expanded on autoload
      @tree_state.x_tree(@name)[:open_nodes].push("xx-#{to_cid(object.id.to_s)}") unless @tree_state.x_tree(@name)[:open_nodes].include?("xx-#{to_cid(object.id.to_s)}")
      [
        {
          :id            => to_cid(object.id.to_s).to_s,
          :text          => _("Indexes"),
          :image         => "100/folder.png",
          :tip           => _("Indexes"),
          :load_children => true
        }
      ]
    end
  end
end
