class TreeNodeBuilderAutomate < TreeNodeBuilder
  include CompressedIds

  def generic_node(node)
    ret = super(node)
    @node[:cfmeNoClick] = noclick_node?(@node[:key])
    ret
  end

  private

  def noclick_node?(key)
    id = from_cid(key.split('_').last.split('-').last)
    if key.start_with?("aei-")
      record = MiqAeInstance.find_by_id(id)
    elsif key.start_with?("aen-")
      record = MiqAeNamespace.find_by_id(id)
      record = nil if record.domain?
    end
    record.nil?
  end
end
