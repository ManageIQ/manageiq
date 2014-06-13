class RemoveEmstypeFromEms < ActiveRecord::Migration
  EMSTYPE_FROM_TYPE = {
    "EmsVmware"    => "vmwarews",
    "EmsMicrosoft" => "scvmm",
    "EmsKvm"       => "kvm",
    "EmsRedhat"    => "rhevm",
    "EmsAmazon"    => "ec2",
    "EmsOpenstack" => "openstack",
  }

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    remove_column :ext_management_systems, :emstype
  end

  def down
    add_column :ext_management_systems,    :emstype, :string

    ExtManagementSystem.all.each do |ems|
      ems.update_attributes!(:emstype => EMSTYPE_FROM_TYPE[ems.type])
    end
  end
end
