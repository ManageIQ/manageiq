class RhevmDisk < RhevmObject

  self.top_level_strings  = [:name, :type, :interface, :format, :image_id]
  self.top_level_booleans = [:sparse, :bootable, :wipe_after_delete, :propagate_errors]
  self.top_level_integers = [:size, :provisioned_size, :actual_size]
  self.top_level_objects  = [:vm]

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    parse_first_node(node, :status, hash, :node => [:state])
    hash[:storage_domains] = node.xpath('storage_domains/storage_domain').collect { |n| hash_from_id_and_href(n) }

    if hash[:size].to_i.zero?
      node.xpath('lun_storage/logical_unit/size').each do |size|
        hash[:size] = size.text.to_i
      end
    end

    hash
  end

  def attributes_for_new_disk
    attrs = attributes.dup
    attrs[:storage] = self[:storage_domains].first[:id]
    attrs
  end

end
