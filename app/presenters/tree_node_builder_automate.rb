class TreeNodeBuilderAutomate < TreeNodeBuilder
  include CompressedIds

  def miq_ae_node(enabled, text, image, tip)
    ret = super(enabled, text, image, tip)
    @node[:cfmeNoClick] = noclick_node?(@node[:key])
    ret
  end

  def generic_node(text, image, tip = nil)
    ret = super(text, image, tip)
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
