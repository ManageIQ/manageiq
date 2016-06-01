class TreeBuilderSnapshots < TreeBuilder

  has_kids_for Snapshot, [:x_get_tree_snapshot_kids]

  def initialize(name, type, sandbox, build = true, root = nil)
    @record = root
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix => "snap_",
        :autoload => true,
        :onclick => 'miqOnClickSnapshotTree',
        :open_close_all_on_dbl_click => true
    )
  end

  def root_options
    [@record.name, @record_name, 'vm', {:cfmeNoClick => true}]
  end

  def x_get_tree_roots(count_only = false, _options)
    root_kid = @record.snapshots.present? ? [@record.snapshots.find{ |x| x.parent_id.nil?}] : []
    count_only_or_objects(count_only, root_kid)
  end

  def x_get_tree_snapshot_kids(parent, count_only)
    kids = parent.children.present? ? parent.children : []
    count_only_or_objects(count_only, kids)
  end
end