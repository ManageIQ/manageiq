require "spec_helper"

describe ManageIQ::Providers::Microsoft::InfraManager::Provision do
  let(:vm_prov) do
    FactoryGirl.create(
      :miq_provision_microsoft,
      :userid       => @admin.userid,
      :miq_request  => @pr,
      :source       => @vm_template,
      :request_type => 'template',
      :state        => 'pending',
      :status       => 'Ok',
      :options      => @options
    )
  end

  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      @admin       = FactoryGirl.create(:user_admin)
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
      @pr          = FactoryGirl.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
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
      it "#workflow" do
        workflow_class = ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow
        workflow_class.any_instance.stub(:get_dialogs).and_return(:dialogs => {})

        expect(vm_prov.workflow.class).to eq workflow_class
        expect(vm_prov.workflow_class).to eq workflow_class
      end
    end

    context "#prepare_for_clone_task" do
      before do
        @host = FactoryGirl.create(:host_microsoft, :ems_ref => "test_ref")
        vm_prov.stub(:dest_host).and_return(@host)
      end

      it "with default options" do
        clone_options = vm_prov.prepare_for_clone_task
        clone_options[:name].should == @target_vm_name
        clone_options[:host].should == @host
      end
    end

    context "#parse mount point" do
      before do
        ds_name = "file://server.local/C:/ClusterStorage/CLUSP04%20Prod%20Volume%203-1"
        @datastore = FactoryGirl.create(:storage, :name => ds_name)
        vm_prov.stub(:dest_datastore).and_return(@datastore)
      end

      it "valid drive" do
        vm_prov.dest_mount_point.should == "C:\\ClusterStorage\\CLUSP04 Prod Volume 3-1"
      end
    end

    context "#no network adapter available" do
      it "set adapter" do
        expect(vm_prov.network_adapter_ps_script).to be_nil
      end
    end

    context "#network adapter available" do
      before do
        @options[:vlan] = "virtualnetwork1"
      end

      it "set adapter" do
        expect(vm_prov.network_adapter_ps_script).to_not be_nil
      end
    end

    context "#no cpu limit or reservation set" do
      before do
        @options[:number_of_cpus] = 2
        @options[:cpu_limit]      = nil
        @options[:cpu_reserve]    = nil
      end

      it "set vm" do
        vm_prov.cpu_ps_script.should == "-CPUCount 2 "
      end
    end

    context "#cpu limit set" do
      before do
        @options[:cpu_limit]      = 40
        @options[:cpu_reserve]    = nil
        @options[:number_of_cpus] = 2
      end

      it "set vm" do
        vm_prov.cpu_ps_script.should == "-CPUCount 2 -CPUMaximumPercent 40 "
      end
    end

    context "#cpu reservations set" do
      before do
        @options[:cpu_reserve]    = 15
        @options[:cpu_limit]      = nil
        @options[:number_of_cpus] = 2
      end

      it "set vm" do
        vm_prov.cpu_ps_script.should == "-CPUCount 2 -CPUReserve 15 "
      end
    end
  end
end
