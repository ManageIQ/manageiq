class Patch < ActiveRecord::Base
  belongs_to :vm_or_template
  belongs_to :host

  include ReportableMixin

  virtual_column :v_install_date, :type => :string

  def self.add_elements(vm, xmlNode)
    add_missing_elements(vm, xmlNode, "software/patches")
  end

  def self.add_missing_elements(vm, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    process_array(vm, hashes)
  end

  def self.refresh_patches(host, hashes)
    process_array(host, hashes)
  end

  def self.process_array(parent, hashes)
    EmsRefresh.save_patches_inventory(parent, hashes) unless hashes.blank?
  end

  def self.highest_patch_level(target)
    ret_val = 0
    target.patches.find(:all, :select=>"id, name").collect do |rec|
      level  = rec[:name].split("-")[-1].to_i
      ret_val = level if level > ret_val
    end
    return ret_val.to_s
  end

  def self.xml_to_hashes(xmlNode, findPath)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element do |e|
      nh = e.attributes.to_h
      nh[:is_valid] = nh.delete(:valid)
      result << nh
    end
    result
  end

  def v_install_date
    # Windows install dates do not include times, so only display YYYY-MM-DD format
    self.installed_on.strftime("%Y-%m-%d") unless self.installed_on.nil?
  end
end
