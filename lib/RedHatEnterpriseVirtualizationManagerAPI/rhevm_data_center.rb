class RhevmDataCenter < RhevmObject

  self.top_level_strings  = [:name, :description, :storage_type, :storage_format]

  def self.element_name
    "data_center"
  end

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    parse_first_node(node, :status,  hash, :node           => [:state])
    parse_first_node(node, :version, hash, :attribute_to_i => [:major, :minor])

    supported_versions_node       = node.xpath('supported_versions').first
    supported_versions            = {}
    supported_versions[:versions] = supported_versions_node.xpath('version').collect { |version_node| { :major => version_node['major'].to_i, :minor => version_node['minor'].to_i } }
    hash[:supported_versions]     = supported_versions

    hash
  end

end
