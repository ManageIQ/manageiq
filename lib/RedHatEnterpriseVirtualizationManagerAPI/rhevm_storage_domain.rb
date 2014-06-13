class RhevmStorageDomain < RhevmObject

  self.top_level_strings    = [:name, :type, :storage_format]
  self.top_level_booleans   = [:master]
  self.top_level_integers   = [:available, :used, :committed]
  self.top_level_objects    = [:data_center]

  def self.element_name
    "storage_domain"
  end

  def self.parse_xml(xml)
    node, hash = xml_to_hash(xml)

    parse_first_node(node, :status,  hash, :node => [:state])
    parse_first_node(node, :storage, hash, :node => [:type, :address, :path])
    parse_first_node(node, :storage, hash, :attribute => [:id])

    node.xpath('storage/volume_group').each do |vg|
      node.xpath('storage').each do |storage_node|
        parse_first_node(storage_node, :volume_group, hash[:storage], :attribute => [:id])
      end

      vg_hash = hash[:storage][:volume_group]
      unless vg_hash.blank?
        parse_first_node(vg, :logical_unit, vg_hash, :attribute => [:id])

        unless vg_hash.blank?
          parse_first_node(vg, :logical_unit, vg_hash,
            :node => [:address, :port, :target, :username, :serial, :vendor_id, :product_id, :lun_mapping, :portal, :size, :paths])
        end
      end
    end

    hash
  end

  def self.iso_storage_domain(service)
    all(service).detect { |s| s[:type] == "iso" }
  end

  def iso_images
    return [] if self[:type] != "iso"
    @service.standard_collection(relationships[:files], 'file')
  end
end
