require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Provision do
  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      @admin = FactoryGirl.create(:user_admin)
      @target_vm_name = 'clone test'
      @options = {
        :pass          => 1,
        :vm_name       => @target_vm_name,
        :number_of_vms => 1,
        :cpu_limit     => -1,
        :cpu_reserve   => 0
      }
    end

    context "VMware provisioning" do
      before(:each) do
        @ems         = FactoryGirl.create(:ems_vmware_with_authentication)
        @vm_template = FactoryGirl.create(:template_vmware, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryGirl.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx")
        @pr          = FactoryGirl.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
        @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
        @vm_prov = FactoryGirl.create(:miq_provision_vmware, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
      end

      it "#workflow" do
        workflow_class = ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow
        workflow_class.any_instance.stub(:get_dialogs).and_return(:dialogs => {})

        expect(@vm_prov.workflow.class).to eq workflow_class
        expect(@vm_prov.workflow_class).to eq workflow_class
      end

      it "should return a config spec" do
        @vm_prov.options.merge!(:vm_memory => '1024', :number_of_cpus => 2)
        @vm_prov.phase_context[:new_vm_validation_guid] = "12345"
        @vm_prov.destination = @vm_template
        @vm_prov.should_receive(:build_config_network_adapters)
        spec = @vm_prov.build_config_spec
        spec.should be_kind_of(VimHash)
        spec.xsiType.should == 'VirtualMachineConfigSpec'
        spec["memoryMB"].should == 1024
        spec["numCPUs"].should == 2
        spec["annotation"].should include(@vm_prov.phase_context[:new_vm_validation_guid])
      end

      it "should return a transform spec" do
        spec = @vm_prov.build_transform_spec
        spec.should be_nil
        @vm_prov.options.merge!(:disk_format => 'thin')
        spec = @vm_prov.build_transform_spec
        spec.should be_kind_of(VimString)
        spec.vimType.should == 'VirtualMachineRelocateTransformation'
      end

      it "should detect when a reconfigure_hardware_on_destination call is required" do
        target_vm = FactoryGirl.create(:vm_vmware, :name => "target_vm1", :location => "abc/def.vmx", :cpu_limit => @vm_prov.options[:cpu_limit])
        @vm_prov.destination = target_vm
        @vm_prov.reconfigure_hardware_on_destination?.should == false
        @vm_prov.options[:cpu_limit] = 100
        @vm_prov.reconfigure_hardware_on_destination?.should == true
      end

      it "should delete unneeded network cards" do
        requested_networks = [{:network => "Build", :devicetype => "VirtualE1000"}, {:network => "Enterprise", :devicetype => "VirtualE1000"}]
        template_networks  = [{"connectable" => {"startConnected" => "true"}, "unitNumber" => "7", "controllerKey" => "100", "addressType" => "assigned", "macAddress" => "00:50:56:af:00:50", "deviceInfo" => {"label" => "Network adapter 1", "summary" => "VM Network"}, "backing" => {"deviceName" => "VM Network", "network" => "network-658"}, "key" => "4000"}]

        @vm_prov.stub(:normalize_network_adapter_settings).and_return(requested_networks)
        @vm_prov.stub(:get_network_adapters).and_return(template_networks)
        @vm_prov.should_receive(:build_config_spec_vlan).twice

        vmcs = VimHash.new("VirtualMachineConfigSpec")
        -> { @vm_prov.build_config_network_adapters(vmcs) }.should_not raise_error
      end

      it "eligible_hosts" do
        host = FactoryGirl.create(:host, :ext_management_system => @ems)
        host_struct = [MiqHashStruct.new(:id => host.id, :evm_object_class => host.class.base_class.name.to_sym)]
        MiqProvisionWorkflow.any_instance.stub(:allowed_hosts).and_return(host_struct)
        @vm_prov.eligible_resources(:hosts).should == [host]
      end

      it "eligible_resources with bad resource" do
        expect { @vm_prov.eligible_resources(:bad_resource_name) }.to raise_error(NameError)
      end

      it "disable customization_spec" do
        @vm_prov.should_receive(:disable_customization_spec).once
        @vm_prov.set_customization_spec(nil).should be_true
      end

      context "with destination VM" do
        before(:each) do
          @vm_prov.destination = Vm.first
          @vm_prov.destination.ext_management_system = @ems
          @vm_prov.stub(:my_zone).and_return("default")
        end

        it "autostart_destination, vm_auto_start disabled" do
          @vm_prov.destination.should_not_receive(:start)
          @vm_prov.should_receive(:post_create_destination)
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination" do
          @vm_prov.options[:vm_auto_start] = true
          @vm_prov.destination.should_receive(:start)
          @vm_prov.should_receive(:post_create_destination)
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination with error" do
          @vm_prov.options[:vm_auto_start] = true
          @vm_prov.destination.stub(:start).and_raise
          @vm_prov.destination.should_receive(:start).once
          @ems.should_receive(:reset_vim_cache).never
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination with MiqVimResourceNotFound" do
          @vm_prov.options[:vm_auto_start] = true
          @vm_prov.destination.stub(:start).and_raise(MiqException::MiqVimResourceNotFound)
          @vm_prov.destination.should_receive(:start).twice
          @ems.should_receive(:reset_vim_cache).once
          @vm_prov.signal :autostart_destination
        end
      end
    end
  end
end
