class RegistryItem < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :miq_set    # ScanItemSet
  belongs_to :scan_item

  include FilterableMixin

  def self.add_elements(miq_set, scan_item, vm, xmlNode)
    @miq_set_id = miq_set.id
    @scan_item_id = scan_item.id

    hashes = xml_to_hashes(xmlNode)
    return if hashes.nil?

    new_reg = []
    deletes = vm.registry_items.pluck(:id, :name)

    hashes.each do |nh|
      found = vm.registry_items.find_by(:name => nh[:name])
      if found.nil?
        new_reg << nh
      elsif nh[:data] != found[:data]
        found.update(nh)
      end
      deletes.delete_if { |ele| ele[1] == nh[:name] }
    end

    vm.registry_items.build(new_reg)
    # Delete the IDs that correspond to the remaining names in the current list.
    _log.info("RegistryItem deletes: #{deletes.inspect}") unless deletes.empty?
    RegistryItem.delete(deletes.transpose[0])
  end

  def self.xml_to_hashes(xmlNode)
    return nil unless MiqXml.isXmlElement?(xmlNode)

    results = []
    xmlNode.each_element('registry') do |el|
      results += process_sub_xml(el, el.attributes['base_path'].to_s)
    end
    results
  end

  def self.process_sub_xml(xmlNode, path)
    results = []
    xmlNode.each_element do |e|
      if e.name == 'key'
        results += process_sub_xml(e, path + '\\' + e.attributes['keyname'])
      elsif e.name == 'value'
        nh = e.attributes.to_h

        nh[:value_name] = nh[:name]
        nh[:data] = e.text
        nh[:name] = path + ' : ' + nh[:name]
        nh[:format] = nh.delete(:type)

        nh[:miq_set_id] = @miq_set_id
        nh[:scan_item_id] = @scan_item_id

        results << nh
      end
    end
    results
  end

  def key_name
    # Remove the value plus the ' : ' separator from the name
    name[0...-value_name.length - 3]
  end

  def image_name
    return "registry_string_items" if !format.blank? && format.include?("_SZ")
    "registry_binary_items"
  end
end
