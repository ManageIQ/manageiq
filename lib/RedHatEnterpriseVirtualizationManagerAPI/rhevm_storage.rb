class RhevmStorage < RhevmObject

  self.top_level_objects  = [:host]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    parse_first_node(node, :volume_group, hash, :attribute => [:id])

    hash
  end

end
