describe ServiceTemplateTransformationPlanTask do
  describe '.base_model' do
    it { expect(described_class.base_model).to eq(ServiceTemplateTransformationPlanTask) }
  end

  describe '#after_request_task_create' do
    it 'does not create child tasks' do
      allow(subject).to receive(:source).and_return(double('vm', :name => 'any'))
      expect(subject).not_to receive(:create_child_tasks)
      expect(subject).to receive(:update_attributes).with(hash_including(:description))
      subject.after_request_task_create
    end
  end

  context 'independent of provider' do
    let(:src) { FactoryGirl.create(:ems_cluster) }
    let(:dst) { FactoryGirl.create(:ems_cluster) }
    let(:host) { FactoryGirl.create(:host, :ext_management_system => FactoryGirl.create(:ext_management_system, :zone => FactoryGirl.create(:zone))) }
    let(:vm)  { FactoryGirl.create(:vm_or_template) }
    let(:vm2)  { FactoryGirl.create(:vm_or_template) }
    let(:apst) { FactoryGirl.create(:service_template_ansible_playbook) }
    let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => host) }

    let(:mapping) do
      FactoryGirl.create(
        :transformation_mapping,
        :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
      )
    end

    let(:catalog_item_options) do
      {
        :name        => 'Transformation Plan',
        :description => 'a description',
        :config_info => {
          :transformation_mapping_id => mapping.id,
          :pre_service_id            => apst.id,
          :post_service_id           => apst.id,
          :actions                   => [
            {:vm_id => vm.id.to_s, :pre_service => true, :post_service => true},
            {:vm_id => vm2.id.to_s, :pre_service => false, :post_service => false},
          ],
        }
      }
    end

    let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }

    let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }
    let(:task) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => vm) }
    let(:task2) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => vm2) }

    describe '#resource_action' do
      it 'has a resource action points to the entry point for transformation' do
        expect(task.resource_action).to have_attributes(
          :action => 'Provision',
          :fqname => ServiceTemplateTransformationPlan.default_provisioning_entry_point(nil)
        )
      end
    end

    describe '#transformation_destination' do
      it { expect(task.transformation_destination(src)).to eq(dst) }
    end

    describe '#pre_ansible_playbook_service_template' do
      it { expect(task.pre_ansible_playbook_service_template).to eq(apst) }
      it { expect(task2.pre_ansible_playbook_service_template).to be_nil }
    end

    describe '#post_ansible_playbook_service_template' do
      it { expect(task.post_ansible_playbook_service_template).to eq(apst) }
      it { expect(task2.post_ansible_playbook_service_template).to be_nil }
    end

    describe '#update_transformation_progress' do
      it 'saves the progress in options' do
        task.update_transformation_progress(:vm_percent => '80')
        expect(task.options[:progress]).to eq(:vm_percent => '80')
      end
    end

    describe 'task_active' do
      it 'sets vm_request status to Started' do
        task.task_active
        expect(plan.vm_resources.find_by(:resource => task.source).status).to eq(ServiceResource::STATUS_ACTIVE)
      end
    end

    describe 'task_finished' do
      it 'sets vm_request status to Completed' do
        task.task_finished
        expect(plan.vm_resources.find_by(:resource => task.source).status).to eq(ServiceResource::STATUS_COMPLETED)
      end
    end

    describe '.get_description' do
      it 'describes a task' do
        expect(described_class.get_description(task)).to include("Transforming VM")
      end

      it 'describes a request' do
        expect(described_class.get_description(request)).to eq(plan.name)
      end
    end

    describe '#transformation_log_queue' do
      context 'when conversion host exists' do
        before do
          task.conversion_host = conversion_host

          allow(described_class).to receive(:find).and_return(task)

          allow(MiqTask).to receive(:wait_for_taskid) do
            request = MiqQueue.find_by(:class_name => described_class.name)
            request.update_attributes(:state => MiqQueue::STATE_DEQUEUE)
            request.delivered(*request.deliver)
          end
        end

        it 'gets the transformation log from conversion host' do
          expect(task).to receive(:transformation_log).and_return('transformation migration log content')
          taskid = task.transformation_log_queue('user')
          MiqTask.wait_for_taskid(taskid)
          expect(MiqTask.find(taskid)).to have_attributes(
            :task_results => 'transformation migration log content',
            :status       => 'Ok'
          )
        end

        it 'returns the error message' do
          msg = 'Failed to get transformation migration log for some reason'
          expect(task).to receive(:transformation_log).and_raise(msg)
          taskid = task.transformation_log_queue('user')
          MiqTask.wait_for_taskid(taskid)
          expect(MiqTask.find(taskid).message).to include(msg)
          expect(MiqTask.find(taskid).status).to eq('Error')
        end
      end

      context 'when conversion host does not exist' do
        it 'returns an error message' do
          taskid = task.transformation_log_queue('user')
          expect(MiqTask.find(taskid)).to have_attributes(
            :message => "Conversion host was not found. Cannot queue the download of transformation log.",
            :status  => 'Error'
          )
        end
      end
    end

    describe '#transformation_log' do
      before do
        task.conversion_host = conversion_host
        task.options.store_path(:virtv2v_wrapper, "v2v_log", "/path/to/log.file")
        task.save!
      end

      it 'requires transformation log location in options' do
        task.options.store_path(:virtv2v_wrapper, "v2v_log", "")
        expect { task.transformation_log }.to raise_error(MiqException::Error)
      end

      it 'gets the transformation log content' do
        msg = 'my transformation migration log'
        allow(conversion_host).to receive(:get_conversion_log).with(task.options[:virtv2v_wrapper]['v2v_log']).and_return(msg)
        expect(task.transformation_log).to eq(msg)
      end
    end

    describe '#mark_vm_migrated' do
      it 'should tag VM as migrated' do
        task.mark_vm_migrated
        expect(vm).to be_is_tagged_with("migrated", :ns => "/managed", :cat => "transformation_status")
      end
    end

    describe '#cancel' do
      it 'catches cancel state' do
        task.cancel
        expect(task.cancelation_status).to eq(MiqRequestTask::CANCEL_STATUS_REQUESTED)
        expect(task.cancel_requested?).to be_truthy
      end
    end

    describe '#kill_virtv2v' do
      before do
        task.conversion_host = conversion_host
        task.options = { :virtv2v_wrapper => {}}
      end

      it "does nothing if pid not present in options[:virtv2v_wrapper]" do
        expect(task.kill_virtv2v('KILL')).to eq(false)
      end

      it "returns false if if kill command failed" do
        task.options[:virtv2v_wrapper]['pid'] = '1234'
        allow(conversion_host).to receive(:kill_process).with('1234', 'KILL').and_return(false)
        expect(task.kill_virtv2v('KILL')).to eq(false)
      end

      it "returns true if if kill command succeeded" do
        task.options[:virtv2v_wrapper]['pid'] = '1234'
        allow(conversion_host).to receive(:kill_process).with('1234', 'KILL').and_return(true)
        expect(task.kill_virtv2v('KILL')).to eq(true)
      end
    end
  end

  context 'populated request and task' do
    let(:src_ems) { FactoryGirl.create(:ext_management_system, :zone => FactoryGirl.create(:zone)) }
    let(:src_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => src_ems) }
    let(:dst_ems) { FactoryGirl.create(:ext_management_system, :zone => FactoryGirl.create(:zone)) }
    let(:dst_cluster) { FactoryGirl.create(:ems_cluster, :ext_management_system => dst_ems) }

    let(:src_vm_1)  { FactoryGirl.create(:vm_or_template, :ext_management_system => src_ems, :ems_cluster => src_cluster) }
    let(:src_vm_2)  { FactoryGirl.create(:vm_or_template, :ext_management_system => src_ems, :ems_cluster => src_cluster) }
    let(:apst) { FactoryGirl.create(:service_template_ansible_playbook) }

    let(:dst_flavor) { FactoryGirl.create(:flavor) }
    let(:dst_security_group) { FactoryGirl.create(:security_group) }

    let(:mapping) do
      FactoryGirl.create(
        :transformation_mapping,
        :transformation_mapping_items => [TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster)]
      )
    end

    let(:catalog_item_options) do
      {
        :name        => 'Transformation Plan',
        :description => 'a description',
        :config_info => {
          :transformation_mapping_id => mapping.id,
          :pre_service_id            => apst.id,
          :post_service_id           => apst.id,
          :actions                   => [
            {:vm_id => src_vm_1.id.to_s, :pre_service => true, :post_service => true, :osp_flavor_id => dst_flavor.id, :osp_security_group_id => dst_security_group.id},
            {:vm_id => src_vm_2.id.to_s, :pre_service => false, :post_service => false},
          ],
        }
      }
    end

    let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
    let(:request) { FactoryGirl.create(:service_template_transformation_plan_request, :source => plan) }
    let(:task_1) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm_1) }
    let(:task_2) { FactoryGirl.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm_2) }

    let(:conversion_host) { FactoryGirl.create(:conversion_host) }

    describe '#transformation_destination' do
      it { expect(task_1.transformation_destination(src_cluster)).to eq(dst_cluster) }
    end

    describe '#pre_ansible_playbook_service_template' do
      it { expect(task_1.pre_ansible_playbook_service_template).to eq(apst) }
      it { expect(task_2.pre_ansible_playbook_service_template).to be_nil }
    end

    describe '#post_ansible_playbook_service_template' do
      it { expect(task_1.post_ansible_playbook_service_template).to eq(apst) }
      it { expect(task_2.post_ansible_playbook_service_template).to be_nil }
    end

    shared_examples_for "#run_conversion" do
      let(:time_now) { Time.now.utc }
      before do
        allow(Time).to receive(:now).and_return(time_now)
        allow(conversion_host).to receive(:run_conversion).with(task_1.conversion_options).and_return(
          {
            "wrapper_log" => "/tmp/wrapper.log",
            "v2v_log"     => "/tmp/v2v.log",
            "state_file"  => "/tmp/v2v.state"
          }
        )
      end

      it "collects the wrapper state hash" do
        task_1.run_conversion
        expect(task_1.options[:virtv2v_wrapper]).to eq(
          {
            "wrapper_log" => "/tmp/wrapper.log",
            "v2v_log"     => "/tmp/v2v.log",
            "state_file"  => "/tmp/v2v.state"
          }
        )
       expect(task_1.options[:virtv2v_started_on]).to eq(time_now.strftime('%Y-%m-%d %H:%M:%S'))
       expect(task_1.options[:virtv2v_status]).to eq('active')
      end
    end

    context 'source is vmwarews' do
      let(:src_ems) { FactoryGirl.create(:ems_vmware, :zone => FactoryGirl.create(:zone)) }
      let(:src_host) { FactoryGirl.create(:host, :ext_management_system => src_ems, :ipaddress => '10.0.0.1') }
      let(:src_storage) { FactoryGirl.create(:storage, :ext_management_system => src_ems) }

      let(:src_lan_1) { FactoryGirl.create(:lan) }
      let(:src_lan_2) { FactoryGirl.create(:lan) }
      let(:src_nic_1) { FactoryGirl.create(:guest_device_nic, :lan => src_lan_1) }
      let(:src_nic_2) { FactoryGirl.create(:guest_device_nic, :lan => src_lan_2) }

      let(:src_disk_1) { instance_double("disk", :device_name => "Hard disk 1", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm.vmdk", :size => 17_179_869_184) }
      let(:src_disk_2) { instance_double("disk", :device_name => "Hard disk 2", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm-2.vmdk", :size => 17_179_869_184) }

      let(:src_hardware) { FactoryGirl.create(:hardware, :nics => [src_nic_1, src_nic_2]) }

      let(:src_vm_1) { FactoryGirl.create(:vm_vmware, :ext_management_system => src_ems, :ems_cluster => src_cluster, :host => src_host, :hardware => src_hardware) }
      let(:src_vm_2) { FactoryGirl.create(:vm_vmware, :ext_management_system => src_ems, :ems_cluster => src_cluster, :host => src_host) }

      let(:src_network) { FactoryGirl.create(:network, :ipaddress => '10.0.0.1') }

      # Disks have to be stubbed because there's no factory for Disk class
      before do
        allow(src_hardware).to receive(:disks).and_return([src_disk_1, src_disk_2])
        allow(src_disk_1).to receive(:storage).and_return(src_storage)
        allow(src_disk_2).to receive(:storage).and_return(src_storage)
        allow(src_vm_1).to receive(:allocated_disk_storage).and_return(34_359_738_368)
        allow(src_nic_1).to receive(:network).and_return(src_network)
        allow(src_host).to receive(:thumbprint_sha1).and_return('01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67')
        allow(src_host).to receive(:authentication_userid).and_return('esx_user')
        allow(src_host).to receive(:authentication_password).and_return('esx_passwd')
        task_1.options[:transformation_host_id] = conversion_host.id
      end

      it "fails when cluster is not mapped" do
        allow(task_1).to receive(:transformation_destination).with(src_cluster).and_return(nil)
        expect { task_1.destination_cluster }.to raise_error("[#{src_vm_1.name}] Cluster #{src_cluster} has no mapping.")
      end

      it "finds the source ems based on source vm" do
        expect(task_1.source_ems).to eq(src_ems)
      end

      it 'find the destination ems based on mapping' do
        expect(task_1.destination_ems).to eq(dst_ems)
      end

      shared_examples_for "get_conversion_state" do
        let(:time_now) { Time.now.utc }
        before do
          allow(Time).to receive(:now).and_return(time_now)
        end

        it "raises when conversion is failed" do
          allow(conversion_host).to receive(:get_conversion_state).with(task.options[:virtv2v_wrapper]['state_file']).and_return(
            {
              "failed"      => true,
              "finished"    => true,
              "started"     => true,
              "disks"       => [
                { "path" => src_disk_1.filename, "progress" => 23.0 },
                { "path" => src_disk_1.filename, "progress" => 0.0 }
              ],
              "pid"         => 5855,
              "return_code" => 1,
              "disk_count"  => 2
            }
          )
          expect { task_1.get_conversion_state }.to raise_error("Disks transformation failed.")
          expect(task_1.options[:virtv2v_status]).to eq('failed')
          epxect(task_1.options[:virtv2v_finished_on]).to eq(time_now.strftime('%Y-%m-%d %H:%M:%S'))
        end

        it "updates disks progress" do
          allow(conversion_host).to receive(:get_conversion_state).with(task.options[:virtv2v_wrapper]['state_file']).and_return(
            {
              "started"     => true,
              "disks"       => [
                { "path" => src_disk_1.filename, "progress" => 100.0 },
                { "path" => src_disk_1.filename, "progress" => 50.0 }
              ],
              "pid"         => 5855,
              "disk_count"  => 2
            }
          )
          task_1.get_conversion_state
          expect(task_1.options[:virtv2v_disks]).to eq(
            [
              { :path => src_disk_1.filename, :size => disk.size, :percent => 100, :weight  => 50 },
              { :path => src_disk_2.filename, :size => disk.size, :percent => 50, :weight  => 50 }
            ]
          )
          expect(task_1.options[:virtv2v_status]).to eq('active')
        end

        it "sets disks progress to 100% when conversion is finished and successful" do
          allow(conversion_host).to receive(:get_conversion_state).with(task.options[:virtv2v_wrapper]['state_file']).and_return(
            {
              "finished"    => true,
              "started"     => true,
              "disks"       => [
                { "path" => src_disk_1.filename, "progress" => 100.0},
                { "path" => src_disk_1.filename, "progress" => 100.0}
              ],
              "pid"         => 5855,
              "return_code" => 0,
              "disk_count"  => 1
            }
          )
          task_1.get_conversion_state
          expect(task.options[:virtv2v_disks]).to eq(
            [
              { :path => src_disk_1.filename, :size => disk.size, :percent => 100, :weight  => 50 },
              { :path => src_disk_2.filename, :size => disk.size, :percent => 100, :weight  => 50 }
            ]
          )
          expect(task_1.options[:virtv2v_status]).to eq('finished')
          epxect(task_1.options[:virtv2v_finished_on]).to eq(time)
        end
      end

      shared_examples_for "#virtv2v_disks" do
        it "checks mapping and generates virtv2v_disks hash" do
          expect(task_1.virtv2v_disks).to eq(
            [
              { :path => src_disk_1.filename, :size => src_disk_1.size, :percent => 0, :weight  => 50.0 },
              { :path => src_disk_2.filename, :size => src_disk_2.size, :percent => 0, :weight  => 50.0 }
            ]
          )
        end
      end

      context 'destination is rhevm' do
        let(:dst_ems) { FactoryGirl.create(:ems_redhat, :zone => FactoryGirl.create(:zone)) }
        let(:dst_storage) { FactoryGirl.create(:storage) }
        let(:dst_lan_1) { FactoryGirl.create(:lan) }
        let(:dst_lan_2) { FactoryGirl.create(:lan) }
        let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => FactoryGirl.create(:host, :ext_management_system => dst_ems)) }

        let(:mapping) do
          FactoryGirl.create(
            :transformation_mapping,
            :transformation_mapping_items => [
              TransformationMappingItem.new(:source => src_cluster, :destination => dst_cluster),
              TransformationMappingItem.new(:source => src_storage, :destination => dst_storage),
              TransformationMappingItem.new(:source => src_lan_1, :destination => dst_lan_1),
              TransformationMappingItem.new(:source => src_lan_2, :destination => dst_lan_2)
            ]
          )
        end

        before do
          task_1.conversion_host = conversion_host
        end

        it { expect(task_1.destination_cluster).to eq(dst_cluster) }

        it_behaves_like "#virtv2v_disks"

        it "checks network mappings and generates network_mappings hash" do
          expect(task_1.network_mappings).to eq(
            [
              { :source => src_lan_1.name, :destination => dst_lan_1.name, :mac_address => src_nic_1.address, :ip_address => '10.0.0.1' },
              { :source => src_lan_2.name, :destination => dst_lan_2.name, :mac_address => src_nic_2.address, :ip_address => nil }
            ]
          )
        end

        context "transport method is vddk" do
          before do
            conversion_host.vddk_transport_supported = true
          end

          it "generates conversion options hash" do
            expect(task_1.conversion_options).to eq(
              :vm_name             => src_vm_1.name,
              :transport_method    => 'vddk',
              :vmware_fingerprint  => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
              :vmware_uri          => "esx://esx_user@10.0.0.1/?no_verify=1",
              :vmware_password     => 'esx_passwd',
              :rhv_url             => "https://#{dst_ems.hostname}/ovirt-engine/api",
              :rhv_cluster         => dst_cluster.name,
              :rhv_storage         => dst_storage.name,
              :rhv_password        => dst_ems.authentication_password,
              :source_disks        => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings    => task_1.network_mappings,
              :install_drivers     => true,
              :insecure_connection => true
            )
          end

          it_behaves_like "#run_conversion"
        end

        context "transport method is ssh" do
          before do
            conversion_host.vddk_transport_supported = false
            conversion_host.ssh_transport_supported = true
          end

          it "generates conversion options hash" do
            expect(task_1.conversion_options).to eq(
              :vm_name             => "ssh://root@10.0.0.1/vmfs/volumes/#{src_storage.name}/#{src_vm_1.location}",
              :transport_method    => 'ssh',
              :rhv_url             => "https://#{dst_ems.hostname}/ovirt-engine/api",
              :rhv_cluster         => dst_cluster.name,
              :rhv_storage         => dst_storage.name,
              :rhv_password        => dst_ems.authentication_password,
              :source_disks        => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings    => task_1.network_mappings,
              :install_drivers     => true,
              :insecure_connection => true
            )
          end
        end
      end

      context 'destination is openstack' do
        let(:dst_ems) { FactoryGirl.create(:ems_openstack, :api_version => 'v3', :zone => FactoryGirl.create(:zone)) }
        let(:dst_cloud_tenant) { FactoryGirl.create(:cloud_tenant, :name => 'fake tenant', :ext_management_system => dst_ems) }
        let(:dst_cloud_volume_type) { FactoryGirl.create(:cloud_volume_type) }
        let(:dst_cloud_network_1) { FactoryGirl.create(:cloud_network) }
        let(:dst_cloud_network_2) { FactoryGirl.create(:cloud_network) }
        let(:dst_flavor) { FactoryGirl.create(:flavor) }
        let(:dst_security_group) { FactoryGirl.create(:security_group) }
        let(:conversion_host_vm) { FactoryGirl.create(:vm_openstack, :ext_management_system => dst_ems, :cloud_tenant => dst_cloud_tenant) }
        let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => conversion_host_vm) }

        let(:mapping) do
          FactoryGirl.create(
            :transformation_mapping,
            :transformation_mapping_items => [
              TransformationMappingItem.new(:source => src_cluster, :destination => dst_cloud_tenant),
              TransformationMappingItem.new(:source => src_storage, :destination => dst_cloud_volume_type),
              TransformationMappingItem.new(:source => src_lan_1, :destination => dst_cloud_network_1),
              TransformationMappingItem.new(:source => src_lan_2, :destination => dst_cloud_network_2)
            ]
          )
        end

        before do
          task_1.conversion_host = conversion_host
        end

        it { expect(task_1.destination_cluster).to eq(dst_cloud_tenant) }

        it_behaves_like "#virtv2v_disks"

        it "checks network mappings and generates network_mappings hash" do
          expect(task_1.network_mappings).to eq(
            [
              { :source => src_lan_1.name, :destination => dst_cloud_network_1.ems_ref, :mac_address => src_nic_1.address, :ip_address => '10.0.0.1' },
              { :source => src_lan_2.name, :destination => dst_cloud_network_2.ems_ref, :mac_address => src_nic_2.address, :ip_address => nil }
            ]
          )
        end

        context "transport method is vddk" do
          before do
            conversion_host.vddk_transport_supported = true
          end

          it "generates conversion options hash" do
            expect(task_1.conversion_options).to eq(
              :vm_name                    => src_vm_1.name,
              :transport_method           => 'vddk',
              :vmware_fingerprint         => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
              :vmware_uri                 => "esx://esx_user@10.0.0.1/?no_verify=1",
              :vmware_password            => 'esx_passwd',
              :osp_environment            => {
                :os_auth_url             => URI::Generic.build(
                  :scheme => dst_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                  :host   => dst_ems.hostname,
                  :port   => dst_ems.port,
                  :path   => '/v3'
                ).to_s,
                :os_identity_api_version => '3',
                :os_user_domain_name     => dst_ems.uid_ems,
                :os_username             => dst_ems.authentication_userid,
                :os_password             => dst_ems.authentication_password,
                :os_project_name         => dst_cloud_tenant.name
              },
              :osp_server_id              => conversion_host_vm.ems_ref,
              :osp_destination_project_id => dst_cloud_tenant.ems_ref,
              :osp_volume_type_id         => dst_cloud_volume_type.ems_ref,
              :osp_flavor_id              => dst_flavor.ems_ref,
              :osp_security_groups_ids    => [dst_security_group.ems_ref],
              :source_disks               => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings           => task_1.network_mappings
            )
          end
        end

        context "transport method is ssh" do
          before do
            conversion_host.vddk_transport_supported = false
            conversion_host.ssh_transport_supported = true
          end

          it "generates conversion options hash" do
            expect(task_1.conversion_options).to eq(
              :vm_name                    => "ssh://root@10.0.0.1/vmfs/volumes/#{src_storage.name}/#{src_vm_1.location}",
              :transport_method           => 'ssh',
              :osp_environment            => {
                :os_auth_url             => URI::Generic.build(
                  :scheme => dst_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                  :host   => dst_ems.hostname,
                  :port   => dst_ems.port,
                  :path   => '/v3'
                ).to_s,
                :os_identity_api_version => '3',
                :os_user_domain_name     => dst_ems.uid_ems,
                :os_username             => dst_ems.authentication_userid,
                :os_password             => dst_ems.authentication_password,
                :os_project_name         => dst_cloud_tenant.name
              },
              :osp_server_id              => conversion_host_vm.ems_ref,
              :osp_destination_project_id => dst_cloud_tenant.ems_ref,
              :osp_volume_type_id         => dst_cloud_volume_type.ems_ref,
              :osp_flavor_id              => dst_flavor.ems_ref,
              :osp_security_groups_ids    => [dst_security_group.ems_ref],
              :source_disks               => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings           => task_1.network_mappings
            )
          end
        end
      end
    end
  end
end
