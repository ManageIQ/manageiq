class RhevmStatistic < RhevmObject

  self.top_level_strings    = [:name, :description, :type, :unit]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    values               = []
    values_node          = node.xpath('values').first
    values_type          = values_node['type']
    values = values_node.xpath('value').collect do |v|
      datum = v.xpath('datum').text
      case values_type
      when 'INTEGER'
        datum = datum.to_i
      when 'DECIMAL'
        datum = datum.to_f
      else
        raise "unknown Values TYPE of <#{values_type}>"
      end
      datum
    end
    hash[:values]        = values

    [:vm, :nic, :disk].each do |type|
      parent_node = node.xpath(type.to_s).first
      next if parent_node.nil?
      parent = hash_from_id_and_href(parent_node)
      parent[:type] = type
      hash[:parent] = parent
    end

    hash
  end
end
