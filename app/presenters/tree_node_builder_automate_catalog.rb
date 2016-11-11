class TreeNodeBuilderAutomateCatalog < TreeNodeBuilderAutomate
  private

  def noclick_node?(key)
    id = from_cid(key.split('_').last.split('-').last)
    if key.start_with?("aei-")
      record = MiqAeInstance.find_by_id(id)
    end
    record.nil?
  end
end
