class RhevmRole < RhevmObject

  self.top_level_strings  = [:name, :description]
  self.top_level_booleans = [:administrative, :mutable]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    hash
  end

end
