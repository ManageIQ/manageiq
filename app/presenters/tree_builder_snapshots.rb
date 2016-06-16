class TreeBuilderSnapshots < TreeBuilder
  has_kids_for Snapshot, [:x_get_tree_snapshot_kids]

  attr_reader :selected_node

  def initialize(name, type, sandbox, build = true, root = nil, selected_node = nil)
    @record = root
    @selected_node = selected_node.present? ? id(selected_node) : nil
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => "snap_",
                  :autoload                    => true,
                  :onclick                     => 'miqOnClickSnapshotTree',
                  :exp_tree                    => true,
                  :open_close_all_on_dbl_click => true)
  end

  def root_options
    [@record.name, @record.name, 'vm', {:cfmeNoClick => true}]
  end

  def x_get_tree_roots(count_only = false, _options)
    root_kid = @record.snapshots.present? ? [@record.snapshots.find { |x| x.parent_id.nil? }] : []
    open_node("sn-#{to_cid(root_kid.first.id)}") if root_kid.present?
    count_only_or_objects(count_only, root_kid)
  end

  def parent_id(id)
    Snapshot.find(id).parent_id
  end

  def id(kid_id)
    id = kid_id
    while parent_id(kid_id).present?
      kid_id = parent_id(kid_id)
      id = to_cid(id) if id.kind_of?(Fixnum)
      id = "#{to_cid(kid_id)}_sn-#{id}"
    end
    "sn-#{id}"
  end

  def x_get_tree_snapshot_kids(parent, count_only)
    kids = parent.children.present? ? parent.children : []
    if kids.present?
      id = id(kids.first.id)
      open_node(id)
    end
    # select last node if no node was selected
    @selected_node = id(parent.id) if @selected_node.nil? && kids.empty?
    count_only_or_objects(count_only, kids)
  end
end
