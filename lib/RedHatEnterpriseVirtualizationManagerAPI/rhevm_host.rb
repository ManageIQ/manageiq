class RhevmHost < RhevmObject

  self.top_level_strings    = [:name, :type, :address]
  self.top_level_integers   = [:port]
  self.top_level_booleans   = [:storage_manager]
  self.top_level_objects    = [:cluster]

  def self.parse_xml(xml)
    node, hash                      = xml_to_hash(xml)

    hash[:relationships][:host_nics] = hash[:relationships].delete(:nics)

    parse_first_node(node, :status, hash,
                     :node => [:state])

    parse_first_node(node, :power_management, hash,
                     :attribute    => [:type],
                     :node         => [:address, :username, :options],
                     :node_to_bool => [:enabled])

    parse_first_node(node, :ksm, hash,
                     :node_to_bool => [:enabled])

    parse_first_node(node, :transparent_hugepages, hash,
                     :node_to_bool => [:enabled])

    parse_first_node(node, :iscsi, hash,
                     :node => [:initiator])

    parse_first_node(node, :cpu, hash,
                     :node      => [:name],
                     :node_to_i => [:speed])

    parse_first_node_with_hash(node, 'cpu/topology', hash.store_path(:cpu, :topology, {}),
                     :attribute_to_i => [:sockets, :cores])

    parse_first_node(node, :summary, hash,
                     :node_to_i => [:active, :migrating, :total])

    hash
  end
end
