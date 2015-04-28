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

    context "SCVMM provisioning" do
      it "#workflow" do
        MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
        @vm_prov.workflow.class.should eq MiqProvisionMicrosoftWorkflow
      end
    end

    context "#prepare_for_clone_task" do
      before do
        @host = FactoryGirl.create(:host_microsoft, :ems_ref => "test_ref")
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
        @vm_prov.stub(:dest_datastore).and_return(@datastore)
      end

      it "valid drive" do
        @vm_prov.dest_mount_point.should == "C:"
      end
    end

    context "#no network adapter available" do
      it "set adapter" do
        expect(@vm_prov.network_adapter_ps_script).to be_nil
      end
    end

    context "#network adapter available" do
      before do
        @options[:vlan] = "virtualnetwork1"

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

      it "set adapter" do
        expect(@vm_prov.network_adapter_ps_script).to_not be_nil
      end
    end

    context "#no cpu limit or reservation set" do
      before do
        @options[:number_of_cpus] = 2
        @options[:cpu_limit]      = nil
        @options[:cpu_reserve]    = nil

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

      it "set vm" do
        @vm_prov.cpu_ps_script.should == "-CPUCount 2 "
      end
    end

    context "#cpu limit set" do
      before do
        @options[:cpu_limit]      = 40
        @options[:cpu_reserve]    = nil
        @options[:number_of_cpus] = 2

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

      it "set vm" do
        @vm_prov.cpu_ps_script.should == "-CPUCount 2 -CPUMaximumPercent 40 "
      end
    end

    context "#cpu reservations set" do
      before do
        @options[:cpu_reserve]    = 15
        @options[:cpu_limit]      = nil
        @options[:number_of_cpus] = 2

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

      it "set vm" do
        @vm_prov.cpu_ps_script.should == "-CPUCount 2 -CPUReserve 15 "
      end
    end
  end
end
