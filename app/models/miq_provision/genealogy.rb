module MiqProvision::Genealogy
  def set_genealogy(child, parent)
    _log.info("Setting Genealogy Parent to #{parent.class.base_model.name} Name=#{parent.name}, ID=#{parent.id}")
    parent.add_genealogy_child(child)
  end
end
