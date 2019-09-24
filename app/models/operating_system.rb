require 'miq-encode'

class OperatingSystem < ApplicationRecord
  belongs_to :host
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :computer_system
  has_many   :processes, :class_name => 'OsProcess', :dependent => :destroy
  has_many   :event_logs, :dependent => :destroy
  has_many   :firewall_rules, :as => :resource, :dependent => :destroy

  @@os_map = [
    ["windows_generic", %w(winnetenterprise w2k3 win2k3 server2003 winnetstandard servernt)],
    ["windows_generic", %w(winxppro winxp)],
    ["windows_generic", %w(vista longhorn)],
    ["windows_generic", %w(win2k win2000)],
    ["windows_generic", %w(microsoft windows winnt)],
    ["linux_ubuntu",    %w(ubuntu)],
    ["linux_chrome",    %w(chromeos)],
    ["linux_chromium",  %w(chromiumos)],
    ["linux_suse",      %w(suse sles)],
    ["linux_redhat",    %w(redhat rhel)],
    ["linux_fedora",    %w(fedora)],
    ["linux_gentoo",    %w(gentoo)],
    ["linux_centos",    %w(centos)],
    ["linux_debian",    %w(debian)],
    ["linux_coreos",    %w(coreos)],
    ["linux_esx",       %w(vmnixx86 vmwareesxserver esxserver vmwareesxi)],
    ["linux_solaris",   %w(solaris)],
    ["linux_generic",   %w(linux)]
  ]

  def self.add_elements(vm, xmlNode)
    add_missing_elements(vm, xmlNode, "system/os")
    add_missing_elements(vm, xmlNode, "system/account_policy")
  end

  def self.add_missing_elements(vm, xmlNode, findPath)
    nh = xml_to_hashes(xmlNode, findPath)
    return if nh.nil?

    nh.delete(:type)
    if vm.operating_system.nil?
      vm.operating_system = OperatingSystem.new(nh)
    else
      vm.operating_system.update(nh)
    end
  end

  def self.xml_to_hashes(xmlNode, findPath)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    nh = el.attributes.to_h
    if findPath == "system/os"
      nh[:name] = nh.delete(:machine_name)
      nh[:bitness] = nh.delete(:architecture)
      nh[:build_number] = nh.delete(:build)
      nh[:system_type] = system_type(nh[:product_type])
    end
    nh
  end

  def self.system_type(value)
    case value.to_s.downcase
    when "servernt" then "server"
    when "winnt" then "desktop"
    else "unknown"
    end
  end

  def self.normalize_os_name(osName)
    findStr = osName.downcase.gsub(/[^a-z0-9]/, "")
    @@os_map.each do |a|
      a[1].each do |n|
        return a[0] unless findStr.index(n).nil?
      end
    end
    "unknown"
  end

  def self.image_name(obj)
    osName = nil

    # Select most accurate name field
    os = obj.operating_system
    if os
      # check the given field names for possible matching value
      osName = [:distribution, :product_type, :product_name].each do |field|
        os_field = os.send(field)
        break(os_field) if os_field && OperatingSystem.normalize_os_name(os_field) != "unknown"
      end

      # If the normalized name comes back as unknown, nil out the value so we can get it from another field
      if osName.kind_of?(String)
        osName = nil if OperatingSystem.normalize_os_name(osName) == "unknown"
      else
        osName = nil
      end
    end

    # If the OS Name is still blank check the 'user_assigned_os'
    if osName.nil? && obj.respond_to?(:user_assigned_os) && obj.user_assigned_os
      osName = obj.user_assigned_os
    end

    # If the OS Name is still blank check the hardware table
    if osName.nil? && obj.hardware && !obj.hardware.guest_os.nil?
      osName = obj.hardware.guest_os
      # if we get generic linux or unknown back see if the vm name is better
      norm_os = OperatingSystem.normalize_os_name(osName)
      if norm_os == "linux_generic" || norm_os == "unknown"
        vm_name = OperatingSystem.normalize_os_name(obj.name)
        return vm_name unless vm_name == "unknown"
      end
    end

    # If the OS Name is still blank use the name field from the object given
    osName = obj.name if osName.nil?

    # Normalize name to match existing icons
    OperatingSystem.normalize_os_name(osName)
  end

  def self.platform(obj)
    image_name(obj).split("_").first
  end
end
