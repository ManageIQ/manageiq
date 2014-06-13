class RhevmSnapshot < RhevmObject

  self.top_level_strings    = [:description, :snapshot_status, :type]
  self.top_level_timestamps = [:date]
  self.top_level_objects    = [:vm]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    hash
  end
  
  def initialize(service, options = {})
    super
    @relationships[:disks] = self[:href] + "/disks"
  end
  
  def delete
    response = destroy
    while self[:snapshot_status] == "locked" || self[:snapshot_status] == "ok"
      sleep 2
      break if (obj = self.class.find_by_href(@service, self[:href])).nil?
      self.replace(obj)
    end
  end

end
