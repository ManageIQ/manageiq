class RhevmHostNic < RhevmObject

  self.top_level_strings  = [:name, :boot_protocol]
  self.top_level_integers = [:speed]
  self.top_level_objects  = [:host, :network]

  def self.element_name
    "host_nic"
  end

  def self.parse_xml(xml)
    node, hash     = xml_to_hash(xml)

    parse_first_node(node, :status,  hash, :node      => [:state])
    parse_first_node(node, :mac,     hash, :attribute => [:address])
    parse_first_node(node, :ip,      hash, :attribute => [:address, :netmask, :gateway])
    parse_first_node(node, :network, hash, :node      => [:name])

    hash[:bonding] = {}
    node.xpath('bonding/options').each do |opts|
      hash[:bonding][:options] = []
      opts.xpath('option').each do |opt|
        hash[:bonding][:options] << {:name => opt[:name], :value => opt[:value], :type => opt[:type]}
      end
    end

    node.xpath('bonding/slaves').each do |slaves|
      hash[:bonding][:slaves] = {:host_nics => []}
      slaves.xpath('host_nic').each do |slave|
        hash[:bonding][:slaves][:host_nics] << {:id => slave[:id], :href => slave[:href]}
      end
    end

    hash
  end
end
