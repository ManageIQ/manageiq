require "spec_helper"
require Rails.root.join("db/migrate/20130701174443_remove_emstype_from_ems.rb")

describe RemoveEmstypeFromEms do
  migration_context :down do
    let(:ems_stub) { migration_stub(:ExtManagementSystem) }

    it "resets emstype" do
      ems_vmware    = ems_stub.create!(:type => "EmsVmware")
      ems_redhat    = ems_stub.create!(:type => "EmsRedhat")
      ems_amazon    = ems_stub.create!(:type => "EmsAmazon")
      ems_openstack = ems_stub.create!(:type => "EmsOpenstack")
      ems_microsoft = ems_stub.create!(:type => "EmsMicrosoft")
      ems_kvm       = ems_stub.create!(:type => "EmsKvm")

      migrate

      ems_stub.where(:id => ems_vmware.id).first.emstype.should    == "vmwarews"
      ems_stub.where(:id => ems_redhat.id).first.emstype.should    == "rhevm"
      ems_stub.where(:id => ems_amazon.id).first.emstype.should    == "ec2"
      ems_stub.where(:id => ems_openstack.id).first.emstype.should == "openstack"
      ems_stub.where(:id => ems_microsoft.id).first.emstype.should == "scvmm"
      ems_stub.where(:id => ems_kvm.id).first.emstype.should       == "kvm"
    end
  end
end
