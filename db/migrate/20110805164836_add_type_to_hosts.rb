class AddTypeToHosts < ActiveRecord::Migration
  class Host < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def self.up
    add_column    :hosts, :type, :string

    # Adjust data in columns to match the new model
    say_with_time("Updating Type in Hosts") do
      Host.all.each { |h| h.update_attribute(:type, detect_type(h)) }
    end
  end

  def self.down
    remove_column :hosts, :type
  end

  def self.detect_type(host)
    if    host.vmm_vendor.downcase  == "vmware"
      return 'HostVmwareEsx' if host.vmm_product.downcase == "esx"
      return 'HostVmwareEsx' if host.vmm_product.downcase == "esxi"
    elsif host.vmm_vendor.downcase  == "microsoft"
      return "HostMicrosoft"
    elsif host.vmm_vendor.downcase  == "kvm"
      return "HostKvm"
    elsif host.vmm_vendor.downcase  == "ec2"
      return "HostAmazon"
    end
    return nil
  end
end
