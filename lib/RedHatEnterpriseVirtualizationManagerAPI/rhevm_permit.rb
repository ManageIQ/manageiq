class RhevmPermit < RhevmObject

  self.top_level_strings  = [:name]
  self.top_level_booleans = [:administrative]
  self.top_level_objects  = [:role]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    hash
  end

end
