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
        allow_any_instance_of(workflow_class).to receive(:get_dialogs).and_return(:dialogs => {})

        expect(@vm_prov.workflow.class).to eq workflow_class
        expect(@vm_prov.workflow_class).to eq workflow_class
      end

      it "should return a config spec" do
        @vm_prov.options.merge!(:vm_memory => '1024', :number_of_cpus => 2)
        @vm_prov.phase_context[:new_vm_validation_guid] = "12345"
        @vm_prov.destination = @vm_template
        expect(@vm_prov).to receive(:build_config_network_adapters)
        spec = @vm_prov.build_config_spec
        expect(spec).to be_kind_of(VimHash)
        expect(spec.xsiType).to eq('VirtualMachineConfigSpec')
        expect(spec["memoryMB"]).to eq(1024)
        expect(spec["numCPUs"]).to eq(2)
        expect(spec["annotation"]).to include(@vm_prov.phase_context[:new_vm_validation_guid])
      end

      it "should return a transform spec" do
        spec = @vm_prov.build_transform_spec
        expect(spec).to be_nil
        @vm_prov.options[:disk_format] = 'thin'
        spec = @vm_prov.build_transform_spec
        expect(spec).to be_kind_of(VimString)
        expect(spec.vimType).to eq('VirtualMachineRelocateTransformation')
      end

      it "should detect when a reconfigure_hardware_on_destination call is required" do
        target_vm = FactoryGirl.create(:vm_vmware, :name => "target_vm1", :location => "abc/def.vmx", :cpu_limit => @vm_prov.options[:cpu_limit])
        @vm_prov.destination = target_vm
        expect(@vm_prov.reconfigure_hardware_on_destination?).to eq(false)
        @vm_prov.options[:cpu_limit] = 100
        expect(@vm_prov.reconfigure_hardware_on_destination?).to eq(true)
      end

      it "should delete unneeded network cards" do
        requested_networks = [{:network => "Build", :devicetype => "VirtualE1000"}, {:network => "Enterprise", :devicetype => "VirtualE1000"}]
        template_networks  = [{"connectable" => {"startConnected" => "true"}, "unitNumber" => "7", "controllerKey" => "100", "addressType" => "assigned", "macAddress" => "00:50:56:af:00:50", "deviceInfo" => {"label" => "Network adapter 1", "summary" => "VM Network"}, "backing" => {"deviceName" => "VM Network", "network" => "network-658"}, "key" => "4000"}]

        allow(@vm_prov).to receive(:normalize_network_adapter_settings).and_return(requested_networks)
        allow(@vm_prov).to receive(:get_network_adapters).and_return(template_networks)
        expect(@vm_prov).to receive(:build_config_spec_vlan).twice

        vmcs = VimHash.new("VirtualMachineConfigSpec")
        expect { @vm_prov.build_config_network_adapters(vmcs) }.not_to raise_error
      end

      it "eligible_hosts" do
        host = FactoryGirl.create(:host, :ext_management_system => @ems)
        host_struct = [MiqHashStruct.new(:id => host.id, :evm_object_class => host.class.base_class.name.to_sym)]
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_hosts).and_return(host_struct)
        expect(@vm_prov.eligible_resources(:hosts)).to eq([host])
      end

      it "eligible_resources with bad resource" do
        expect { @vm_prov.eligible_resources(:bad_resource_name) }.to raise_error(NameError)
      end

      it "disable customization_spec" do
        expect(@vm_prov).to receive(:disable_customization_spec).once
        expect(@vm_prov.set_customization_spec(nil)).to be_truthy
      end

      context "with destination VM" do
        before(:each) do
          @vm_prov.destination = Vm.first
          @vm_prov.destination.ext_management_system = @ems
          allow(@vm_prov).to receive(:my_zone).and_return("default")
        end

        it "autostart_destination, vm_auto_start disabled" do
          expect(@vm_prov.destination).not_to receive(:start)
          expect(@vm_prov).to receive(:post_create_destination)
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination" do
          @vm_prov.options[:vm_auto_start] = true
          expect(@vm_prov.destination).to receive(:start)
          expect(@vm_prov).to receive(:post_create_destination)
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination with error" do
          @vm_prov.options[:vm_auto_start] = true
          allow(@vm_prov.destination).to receive(:start).and_raise
          expect(@vm_prov.destination).to receive(:start).once
          expect(@ems).to receive(:reset_vim_cache).never
          @vm_prov.signal :autostart_destination
        end

        it "autostart_destination with MiqVimResourceNotFound" do
          @vm_prov.options[:vm_auto_start] = true
          allow(@vm_prov.destination).to receive(:start).and_raise(MiqException::MiqVimResourceNotFound)
          expect(@vm_prov.destination).to receive(:start).twice
          expect(@ems).to receive(:reset_vim_cache).once
          @vm_prov.signal :autostart_destination
        end
      end

      context "#dest_folder" do
        let(:user_folder) { FactoryGirl.create(:ems_folder) }

        let(:dc) do
          FactoryGirl.create(:datacenter).tap do |f|
            f.parent = FactoryGirl.create(:ems_folder, :name => 'Datacenters').tap { |d| d.parent = @ems; }
          end
        end

        let(:vm_folder) do
          FactoryGirl.create(:ems_folder, :name => 'vm').tap { |v| v.parent = dc }
        end

        let(:discovered_vm_folder) do
          FactoryGirl.create(:ems_folder, :name => 'Discovered virtual machine').tap { |f| f.parent = vm_folder }
        end

        let(:dest_host) do
          FactoryGirl.create(:host_vmware, :ext_management_system => @ems).tap { |h| h.parent = dc }
        end

        it "uses folder set from option" do
          @vm_prov.options[:placement_folder_name] = [user_folder.id, user_folder.name]
          expect(@vm_prov.dest_folder).to eq(user_folder)
        end

        it "uses 'Discoverd virtual machine' folder in destination host" do
          discovered_vm_folder
          @vm_prov.options[:dest_host] = [dest_host.id, dest_host.name]
          expect(@vm_prov.dest_folder).to eq(discovered_vm_folder)
        end

        it "uses vm folder in destination host" do
          vm_folder
          @vm_prov.options[:dest_host] = [dest_host.id, dest_host.name]
          expect(@vm_prov.dest_folder).to eq(vm_folder)
        end
      end

      context "#dest_resource_pool" do
        let(:resource_pool) { FactoryGirl.create(:resource_pool) }

        let(:dest_host) do
          host = FactoryGirl.create(:host_vmware, :ext_management_system => @ems)
          FactoryGirl.create(:resource_pool).parent = host
          host
        end

        let(:cluster) do
          cluster = FactoryGirl.create(:ems_cluster)
          FactoryGirl.create(:resource_pool).parent = cluster
        end

        let(:dest_host_with_cluster) { FactoryGirl.create(:host_vmware, :ems_cluster => cluster) }

        it "uses the resource pool from options" do
          @vm_prov.options[:placement_rp_name] = resource_pool.id
          expect(@vm_prov.dest_resource_pool).to eq(resource_pool)
        end

        it "uses the resource pool from the cluster" do
          @vm_prov.options[:dest_host] = [dest_host_with_cluster.id, dest_host_with_cluster.name]
          expect(@vm_prov.dest_resource_pool).to eq(cluster.default_resource_pool)
        end

        it "uses the resource pool from destination host" do
          @vm_prov.options[:dest_host] = [dest_host.id, dest_host.name]
          expect(@vm_prov.dest_resource_pool).to eq(dest_host.default_resource_pool)
        end
      end

      context "#start_clone" do
        before(:each) do
          ds_mor = "datastore-0"
          storage = FactoryGirl.create(:storage_nfs, :ems_ref => ds_mor, :ems_ref_obj => ds_mor)

          Array.new(2) do |i|
            host_mor = "host-#{i}"
            host_props = {
              :ext_management_system => @ems,
              :ems_ref               => host_mor,
              :ems_ref_obj           => host_mor
            }

            FactoryGirl.create(:host_vmware, host_props).tap do |host|
              host.storages = [storage]
              hs = host.host_storages.first
              hs.ems_ref = "datastore-#{i}"
              hs.save
            end
          end
        end

        it "uses the ems_ref for the correct host" do
          dest_host_mor      = "host-1"
          dest_datastore_mor = "datastore-1"
          task_mor           = "task-1"

          clone_opts = {
            :name      => @target_vm_name,
            :host      => Host.find_by(:ems_ref => dest_host_mor),
            :datastore => Storage.first
          }

          expected_vim_clone_opts = {
            :name          => @target_vm_name,
            :wait          => false,
            :template      => false,
            :transform     => nil,
            :config        => nil,
            :customization => nil,
            :linked_clone  => nil,
            :host          => dest_host_mor,
            :datastore     => dest_datastore_mor
          }

          allow(@vm_prov).to receive(:clone_vm).with(expected_vim_clone_opts).and_return(task_mor)

          result = @vm_prov.start_clone clone_opts
          expect(result).to eq(task_mor)
        end
      end
    end
  end
end
