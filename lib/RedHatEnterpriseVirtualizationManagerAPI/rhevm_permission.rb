class RhevmPermission < RhevmObject

  self.top_level_objects  = [:role, :user]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    [:template].each do |type|
      subject_node = node.xpath(type.to_s).first
      next if subject_node.nil?
      subject        = hash_from_id_and_href(subject_node)
      subject[:type] = type
      hash[:subject] = subject
    end

    hash
  end
end
