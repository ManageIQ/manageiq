require "spec_helper"

describe MiqProvisionMicrosoft do
  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      User.any_instance.stub(:role).and_return("admin")
      @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
      UiTaskSet.stub(:find_by_name).and_return(@approver)
      @target_vm_name = 'clone test'
      @ems         = FactoryGirl.create(:ems_microsoft_with_authentication)
      @vm_template = FactoryGirl.create(
        :template_microsoft,
        :name                  => "template1",
        :ext_management_system => @ems,
        :operating_system      => @os,
        :cpu_limit             => -1,
        :cpu_reserve           => 0)
      @vm          = FactoryGirl.create(:vm_microsoft, :name => "vm1",       :location => "abc/def.xml")
      @pr          = FactoryGirl.create(:miq_provision_request, :userid => @user.userid, :src_vm_id => @vm_template.id)
      @options = {
        :pass           => 1,
        :vm_name        => @target_vm_name,
        :vm_target_name => @target_vm_name,
        :number_of_vms  => 1,
        :cpu_limit      => -1,
        :cpu_reserve    => 0,
        :provision_type => "microsoft",
        :src_vm_id      => [@vm_template.id, @vm_template.name]
      }
    end

    context "SCVMM provisioning" do
      before(:each) do
        @vm_prov     = FactoryGirl.create(
          :miq_provision_microsoft,
          :userid       => @user.userid,
          :miq_request  => @pr,
          :source       => @vm_template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => @options)
      end

      it "#workflow" do
        MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
        @vm_prov.workflow.class.should eq MiqProvisionMicrosoftWorkflow
      end
    end

    context "#prepare_for_clone_task" do
      before do
        @host = FactoryGirl.create(:host_microsoft, :ems_ref => "test_ref")
        @vm_prov = FactoryGirl.create(
          :miq_provision_microsoft,
          :userid       => @user.userid,
          :miq_request  => @pr,
          :source       => @vm_template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => @options)
        @vm_prov.stub(:dest_host).and_return(@host)
      end

      it "with default options" do
        clone_options = @vm_prov.prepare_for_clone_task
        clone_options[:name].should == @target_vm_name
        clone_options[:host].should == @host
      end
    end

    context "#parse mount point" do
      before do
        @datastore = FactoryGirl.create(:storage, :name => "C:\\directoryname\\test_datastore")
        @vm_prov = FactoryGirl.create(
          :miq_provision_microsoft,
          :userid       => @user.userid,
          :miq_request  => @pr,
          :source       => @vm_template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => @options)
        @vm_prov.stub(:dest_datastore).and_return(@datastore)
      end

      it "valid drive" do
        @vm_prov.dest_mount_point.should == "C:"
      end
    end

    context "#no network adapter available" do
      before do
        @vm_prov = FactoryGirl.create(
          :miq_provision_microsoft,
          :userid       => @user.userid,
          :miq_request  => @pr,
          :source       => @vm_template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => @options)
      end

      it "set adapter" do
        expect(@vm_prov.network_adapter_ps_script).to be_nil
      end
    end

    context "#network adapter available" do
      before do
        @options[:vlan] = "virtualnetwork1"
        @vm_prov = FactoryGirl.create(
          :miq_provision_microsoft,
          :userid       => @user.userid,
          :miq_request  => @pr,
          :source       => @vm_template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => @options)
      end

      it "set adapter" do
        expect(@vm_prov.network_adapter_ps_script).to_not be_nil
      end
    end
  end
end
