class AddTypeToExtManagementSystems < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def self.up
    add_column    :ext_management_systems, :type, :string

    # Adjust data in columns to match the new model
    say_with_time("Updating Type in ExtManagementSystems") do
      ExtManagementSystem.all.each { |ems| ems.update_attribute(:type, detect_type(ems) || "EmsVmware") }
    end
  end

  def self.down
    remove_column :ext_management_systems, :type
  end

  def self.detect_type(ems)
    case ems.emstype.downcase
    when "vmwarews"; "EmsVmware"
    when "scvmm";    "EmsMicrosoft"
    when "kvm";      "EmsKvm"
    when "rhevm";    "EmsRedhat"
    when "ec2";      "EmsAmazon"
    else nil
    end
  end
end
