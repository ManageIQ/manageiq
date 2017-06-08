module EmsRefresh::SaveInventoryMonitoring
  def save_ems_monitoring_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    child_keys = []
    # Save and link other subsections
    child_keys.each do |k|
      send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
  end
end
