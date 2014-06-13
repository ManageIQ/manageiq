class RhevmUser < RhevmObject

  self.top_level_strings  = [:name, :description, :domain, :user_name]
  self.top_level_booleans = [:logged_in]

  def self.parse_xml(xml)
    node, hash    = xml_to_hash(xml)
    groups_node   = node.xpath('groups').first
    hash[:groups] = groups_node.xpath('group').collect { |group_node| group_node.text } unless groups_node.nil?

    hash
  end

end
