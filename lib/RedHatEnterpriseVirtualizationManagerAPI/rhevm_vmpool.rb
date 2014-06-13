class RhevmVmpool < RhevmObject

  self.top_level_strings    = [:name, :description]
  self.top_level_integers   = [:size]
  self.top_level_objects    = [:cluster, :template]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    hash
  end

end
