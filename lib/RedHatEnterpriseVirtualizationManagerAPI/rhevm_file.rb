class RhevmFile < RhevmObject

  self.top_level_strings    = [:name]
  self.top_level_objects    = [:storage_domain]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    hash
  end

end
