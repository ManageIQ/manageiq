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

  OS_MAP = [
    ["windows_generic", %w[winnetenterprise w2k3 win2k3 server2003 winnetstandard servernt]],
    ["windows_generic", %w[winxppro winxp]],
    ["windows_generic", %w[vista longhorn]],
    ["windows_generic", %w[win2k win2000]],
    ["windows_generic", %w[microsoft windows winnt]],
    ["linux_ubuntu",    %w[ubuntu]],
    ["linux_chrome",    %w[chromeos]],
    ["linux_chromium",  %w[chromiumos]],
    ["linux_suse",      %w[suse sles]],
    ["linux_coreos",    %w[coreos rhcos]],
    ["linux_redhat",    %w[redhat rhel]],
    ["linux_fedora",    %w[fedora]],
    ["linux_gentoo",    %w[gentoo]],
    ["linux_centos",    %w[centos]],
    ["linux_debian",    %w[debian]],
    ["linux_esx",       %w[vmnixx86 vmwareesxserver esxserver vmwareesxi]],
    ["linux_solaris",   %w[solaris]],
    ["linux_oracle",    %w[oracle]],
    ["linux_generic",   %w[linux]],
    ["unix_aix",        %w[aix vios]],
    ["ibm_i",           %w[ibmi]],
    ["ibm_power_vm",    %w[phyp]]
  ].freeze

  def self.add_elements(vm, xmlNode)
    add_missing_elements(vm, xmlNode, "system/os")
    add_missing_elements(vm, xmlNode, "system/account_policy")
  end

  def self.add_missing_elements(vm, xmlNode, findPath)
    nh = xml_to_hashes(xmlNode, findPath)
    return if nh.nil?

    nh.delete(:type)
    if vm.operating_system.nil?
      vm.operating_system = new(nh)
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

  def self.normalize_os_name(os_name)
    clean_os_name = os_name.downcase.gsub(/[^a-z0-9]/, "")
    OS_MAP.each do |normalized_name, candidate_names|
      candidate_names.each do |candidate|
        return normalized_name if clean_os_name.include?(candidate)
      end
    end
    "unknown"
  end

  def self.image_name(obj)
    os_name = nil

    # Select most accurate name field
    os = obj.operating_system
    if os
      # check the given field names for possible matching value
      os_name = [:distribution, :product_type, :product_name].each do |field|
        os_field = os.send(field)
        break(os_field) if os_field && normalize_os_name(os_field) != "unknown"
      end

      # If the normalized name comes back as unknown, nil out the value so we can get it from another field
      if os_name.kind_of?(String)
        os_name = nil if normalize_os_name(os_name) == "unknown"
      else
        os_name = nil
      end
    end

    # If the OS Name is still blank check the 'user_assigned_os'
    if os_name.nil? && obj.respond_to?(:user_assigned_os) && obj.user_assigned_os
      os_name = obj.user_assigned_os
    end

    # If the OS Name is still blank check the hardware table
    if os_name.nil? && obj.hardware && !obj.hardware.guest_os.nil?
      os_name = obj.hardware.guest_os
      # if we get generic linux or unknown back see if the vm name is better
      norm_os = normalize_os_name(os_name)
      if ["linux_generic", "unknown"].include?(norm_os)
        vm_name = normalize_os_name(obj.name)
        return vm_name unless vm_name == "unknown"
      end
    end

    # If the OS Name is still blank use the name field from the object given
    os_name = obj.name if os_name.nil?

    # Normalize name to match existing icons
    normalize_os_name(os_name)
  end

  def self.platform(obj)
    image_name(obj).split("_").first
  end
end
