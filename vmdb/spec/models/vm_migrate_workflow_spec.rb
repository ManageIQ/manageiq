require "spec_helper"

describe VmMigrateWorkflow do

  before do
    MiqRegion.seed
  end

  context "With a Valid Template," do
    let(:admin)    { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }
    let(:provider) { FactoryGirl.create(:ems_vmware) }
    let(:vm) { FactoryGirl.create(:vm_vmware, :ext_management_system => provider) }

    before do
      VmMigrateWorkflow.any_instance.stub(:get_dialogs).and_return( {:dialogs => {}} )
      VmMigrateWorkflow.any_instance.stub(:update_field_visibility)
    end

    context "#allowed_hosts" do
      let(:workflow) { VmMigrateWorkflow.new({:src_ids => [vm.id]}, admin.userid) }

      context "#allowed_hosts" do
        it "with no hosts" do
          workflow.allowed_hosts.should == []
        end

        it "with a host" do
          host = FactoryGirl.create(:host_vmware, :ext_management_system => provider)
          host.set_parent(provider)
          workflow.stub(:process_filter).and_return([host])

          workflow.allowed_hosts.should == [workflow.ci_to_hash_struct(host)]
        end

      end
    end
  end

end
