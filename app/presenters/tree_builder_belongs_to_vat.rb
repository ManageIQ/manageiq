class TreeBuilderBelongsToVat < TreeBuilderBelongsToHac

  def node_builder
    TreeNodeBuilderBelongsToVat
  end

  def initialize(name, type, sandbox, build = true, params)
    super(name, type, sandbox, build, params)
  end

  def set_locals_for_render
    locals = super
    locals.merge!(locals.merge!(:id_prefix => 'vat_'))
  end

  def x_get_tree_datacenter_kids(parent, count_only = false, _type)
    kids = []
    parent.folders.each do |child|
      next unless child.kind_of?(EmsFolder)
      next if child.name == "host"
      if child.name == "vm"
        kids.concat(child.folders_only)
      else
        kids.push(child)
      end
    end
    count_only_or_objects(count_only, kids)
  end
end
