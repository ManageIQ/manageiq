module MiqProvision::Genealogy
  def set_genealogy(child, parent)
    log_header = "MIQ(#{self.class.name}#set_genealogy)"

    $log.info "#{log_header} Setting Genealogy Parent to #{parent.class.base_model.name} Name=#{parent.name}, ID=#{parent.id}"
    parent.add_genealogy_child(child)
  end
end
