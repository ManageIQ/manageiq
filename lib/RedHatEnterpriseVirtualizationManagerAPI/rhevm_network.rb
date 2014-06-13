class RhevmNetwork < RhevmObject

  self.top_level_strings  = [:name, :description]
  self.top_level_booleans = [:stp, :display]
  self.top_level_objects  = [:data_center, :cluster, :vlan]

  def self.parse_xml(xml)
    node, hash    = xml_to_hash(xml)

    parse_first_node(node, :status, hash, :node => [:state])

    hash
  end

end
