RSpec.describe ServiceTemplateTransformationPlanTask, :v2v do
  let(:infra_conversion_job) { FactoryBot.create(:infra_conversion_job) }
  let(:src_ems) { FactoryBot.create(:ems_vmware) }
  let(:src_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => src_ems) }

  let(:redhat_ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
  let(:redhat_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => redhat_ems) }
  let(:redhat_hosts) { FactoryBot.create_list(:host, 1, :ems_cluster => redhat_cluster) }
  let(:redhat_storages) { FactoryBot.create_list(:storage, 1, :hosts => redhat_hosts) }
  let(:redhat_switch) { FactoryBot.create(:switch, :ems_id => redhat_ems.id) }
  let(:redhat_lans) { FactoryBot.create_list(:lan, 2, :switch => redhat_switch) }
  let!(:redhat_host_switch) { FactoryBot.create(:host_switch, :host => redhat_hosts.first, :switch => redhat_switch) }

  describe '.base_model' do
    it { expect(described_class.base_model).to eq(ServiceTemplateTransformationPlanTask) }
  end

  describe '#after_request_task_create' do
    it 'does not create child tasks' do
      allow(subject).to receive(:source).and_return(double('vm', :name => 'any'))
      expect(subject).not_to receive(:create_child_tasks)
      expect(subject).to receive(:update!).with(hash_including(:description))
      subject.after_request_task_create
    end
  end

  context 'independent of provider' do
    let(:dst_ems) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
    let(:dst_cluster) { FactoryBot.create(:ems_cluster_openstack, :ext_management_system => dst_ems) }
    let(:host) { FactoryBot.create(:host, :ext_management_system => FactoryBot.create(:ext_management_system, :zone => FactoryBot.create(:zone))) }
    let(:vm) { FactoryBot.create(:vm_or_template) }
    let(:vm2)  { FactoryBot.create(:vm_or_template) }
    let(:apst) { FactoryBot.create(:service_template_ansible_playbook) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :skip_validate, :resource => host) }

    let(:mapping) do
      FactoryBot.create(:transformation_mapping).tap do |tm|
        FactoryBot.create(:transformation_mapping_item,
                          :source                 => src_cluster,
                          :destination            => dst_cluster,
                          :transformation_mapping => tm)
      end
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

    let(:request) { FactoryBot.create(:service_template_transformation_plan_request, :source => plan) }
    let(:task) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => vm) }
    let(:task2) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => vm2) }

    describe '#resource_action' do
      it 'has a resource action points to the entry point for transformation' do
        expect(task.resource_action).to have_attributes(
          :action => 'Provision',
          :fqname => ServiceTemplateTransformationPlan.default_provisioning_entry_point(nil)
        )
      end
    end

    describe '#transformation_destination' do
      it { expect(task.transformation_destination(src_cluster)).to eq(dst_cluster) }
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
            request.update(:state => MiqQueue::STATE_DEQUEUE)
            request.delivered(*request.deliver)
          end
        end

        it 'raises when log type is invalid' do
          msg = "Transformation log type 'invalid' not supported"
          expect { task.transformation_log_queue('user', 'invalid') }.to raise_error(msg)
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
            :message => "Conversion host was not found. Cannot queue the download of v2v log.",
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
        expect { task.transformation_log("v2v") }.to raise_error(MiqException::Error)
      end

      it 'gets the transformation log content' do
        msg = 'my transformation migration log'
        allow(conversion_host).to receive(:get_conversion_log).with(task.options[:virtv2v_wrapper]['v2v_log']).and_return(msg)
        expect(task.transformation_log("v2v")).to eq(msg)
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
        task.options = {
          :virtv2v_pid        => '1234',
          :virtv2v_wrapper    => { 'state_file' => '/tmp/v2v.state' },
          :virtv2v_started_on => 1
        }
        task.conversion_host = conversion_host
        allow(task).to receive(:get_conversion_state).and_return([])
      end

      it "returns false if not started" do
        task.options[:virtv2v_started_on] = nil
        expect(conversion_host).not_to receive(:kill_virtv2v)
        expect(task.kill_virtv2v).to eq(false)
      end

      it "returns false if finished" do
        task.options[:virtv2v_finished_on] = 1
        expect(conversion_host).not_to receive(:kill_virtv2v)
        expect(task.kill_virtv2v).to eq(false)
      end

      it "returns false if virtv2v_wrapper is absent" do
        task.options[:virtv2v_wrapper] = nil
        expect(conversion_host).not_to receive(:kill_virtv2v)
        expect(task.kill_virtv2v).to eq(false)
      end

      it "returns false if if kill command failed" do
        allow(conversion_host).to receive(:kill_virtv2v).with(task.id, 'KILL').and_return(false)
        expect(task.kill_virtv2v('KILL')).to eq(false)
      end

      it "returns true if if kill command succeeded" do
        allow(conversion_host).to receive(:kill_virtv2v).with(task.id, 'KILL').and_return(true)
        expect(task.kill_virtv2v('KILL')).to eq(true)
      end

      it "considers virt-v2v finished or returns false if an exception occurs" do
        Timecop.freeze(2019, 2, 6) do
          allow(task).to receive(:get_conversion_state).and_raise('fake error')
          expect(task.kill_virtv2v('TERM')).to eq(false)
          expect(task.options[:virtv2v_finished_on]).to eq(Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'))
        end
      end
    end
  end

  context 'populated request and task' do
    let(:dst_ems) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
    let(:dst_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => dst_ems) }

    let(:src_vm_1)  { FactoryBot.create(:vm_or_template, :ext_management_system => src_ems, :ems_cluster => src_cluster) }
    let(:src_vm_2)  { FactoryBot.create(:vm_or_template, :ext_management_system => src_ems, :ems_cluster => src_cluster) }
    let(:apst) { FactoryBot.create(:service_template_ansible_playbook) }

    let(:dst_flavor) { FactoryBot.create(:flavor) }
    let(:dst_security_group) { FactoryBot.create(:security_group) }

    let(:mapping) do
      FactoryBot.create(:transformation_mapping).tap do |tm|
        FactoryBot.create(:transformation_mapping_item,
                          :source                 => src_cluster,
                          :destination            => dst_cluster,
                          :transformation_mapping => tm)
      end
    end

    let(:catalog_item_options) do
      {
        :name        => 'Transformation Plan',
        :description => 'a description',
        :config_info => {
          :transformation_mapping_id => mapping.id,
          :pre_service_id            => apst.id,
          :post_service_id           => apst.id,
          :warm_migration            => true,
          :actions                   => [
            {:vm_id => src_vm_1.id.to_s, :pre_service => true, :post_service => true, :osp_flavor_id => dst_flavor.id, :osp_security_group_id => dst_security_group.id},
            {:vm_id => src_vm_2.id.to_s, :pre_service => false, :post_service => false},
          ],
        }
      }
    end

    let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
    let(:request) { FactoryBot.create(:service_template_transformation_plan_request, :source => plan) }
    let(:task_1) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm_1) }
    let(:task_2) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm_2) }

    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => src_vm_1) }

    describe "#valid_states" do
      it "contains 'migrate'" do
        expect(task_1.send(:valid_states)).to include('migrate')
      end
    end

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
        allow(conversion_host).to receive(:run_conversion).with(task_1.id, task_1.conversion_options)
      end

      it "collects the wrapper state hash" do
        task_1.run_conversion
        expect(task_1.options[:virtv2v_wrapper]).to eq(
          "state_file"      => "/var/lib/uci/#{task_1.id}/state.json",
          "throttling_file" => "/var/lib/uci/#{task_1.id}/limits.json",
          "cutover_file"    => "/var/lib/uci/#{task_1.id}/cutover",
          "v2v_log"         => "/var/log/uci/#{task_1.id}/virt-v2v.log",
          "wrapper_log"     => "/var/log/uci/#{task_1.id}/virt-v2v-wrapper.log"
        )
        expect(task_1.options[:virtv2v_started_on]).to eq(time_now.strftime('%Y-%m-%d %H:%M:%S'))
        expect(task_1.options[:virtv2v_status]).to eq('active')
      end
    end

    context 'source is vmwarews' do
      let(:src_host) { FactoryBot.create(:host_vmware_esx, :ems_cluster => src_cluster, :ipaddress => '10.0.0.1') }
      let(:src_storage) { FactoryBot.create(:storage, :hosts => [src_host], :name => 'stockage récent') }
      let(:src_switch) { FactoryBot.create(:switch, :ems_id => src_ems.id) }
      let(:src_lans) { FactoryBot.create_list(:lan, 2, :switch => src_switch) }
      let!(:src_host_switch) { FactoryBot.create(:host_switch, :host => src_host, :switch => src_switch) }
      let(:host_auth) { FactoryBot.create(:authentication, :status_details => 'fake error') }

      let(:src_nic_1) { FactoryBot.create(:guest_device_nic, :lan => src_lans.first) }
      let(:src_nic_2) { FactoryBot.create(:guest_device_nic, :lan => src_lans.last) }

      let(:src_disk_1) { instance_double("disk", :device_name => "Hard disk 1", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm.vmdk", :size => 17_179_869_184) }
      let(:src_disk_2) { instance_double("disk", :device_name => "Hard disk 2", :device_type => "disk", :filename => "[datastore12] test_vm/test_vm-2.vmdk", :size => 17_179_869_184) }

      let(:src_hardware) { FactoryBot.create(:hardware, :nics => [src_nic_1, src_nic_2]) }

      let(:src_vm_1) { FactoryBot.create(:vm_openstack, :ext_management_system => src_ems, :ems_cluster => src_cluster, :host => src_host, :hardware => src_hardware) }
      let(:src_vm_2) { FactoryBot.create(:vm_openstack, :ext_management_system => src_ems, :ems_cluster => src_cluster, :host => src_host) }

      let(:src_network_1) { FactoryBot.create(:network, :ipaddress => '10.0.1.1') }
      let(:src_network_2) { FactoryBot.create(:network, :ipaddress => nil) }

      # Disks have to be stubbed because there's no factory for Disk class
      before do
        allow(src_hardware).to receive(:disks).and_return([src_disk_1, src_disk_2])
        allow(src_disk_1).to receive(:storage).and_return(src_storage)
        allow(src_disk_2).to receive(:storage).and_return(src_storage)
        allow(src_vm_1).to receive(:allocated_disk_storage).and_return(34_359_738_368)
        allow(src_nic_1).to receive(:network).and_return(src_network_1)
        allow(src_nic_2).to receive(:network).and_return(src_network_2)
        allow(src_host).to receive(:thumbprint_sha1).and_return('01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67')
        allow(src_host).to receive(:authentication_userid).and_return('esx_user')
        allow(src_host).to receive(:authentication_password).and_return('esx_passwd')
        task_1.options[:transformation_host_id] = conversion_host.id
        allow(task_1).to receive(:with_lock).and_yield
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

      shared_examples_for "#get_conversion_state" do
        let(:time_now) { Time.now }
        before do
          allow(Time).to receive(:now).and_return(time_now)
          task_1.update_options(
              :virtv2v_disks => [
                { :path => src_disk_1.filename, :size => src_disk_1.size, :percent => 12.0, :weight  => 50 },
                { :path => src_disk_2.filename, :size => src_disk_2.size, :percent => 0.0, :weight  => 50 }
              ],
              :virtv2v_wrapper => {'state_file' => 'fake_state'}
          )
        end

        it "rescues when conversion_host.get_conversion_state fails less than 5 times" do
          task_1.update_options(:get_conversion_state_failures => 2)
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_raise("Fake error")
          task_1.get_conversion_state
          expect(task_1.options[:get_conversion_state_failures]).to eq(3)
        end

        it "rescues when conversion_host.get_conversion_state fails more than 5 times" do
          task_1.update_options(:get_conversion_state_failures => 5)
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_raise("Fake error")
          expect { task_1.get_conversion_state }.to raise_error("Failed to get conversion state 5 times in a row")
          expect(task_1.options[:get_conversion_state_failures]).to eq(6)
        end

        it "updates progress when conversion is failed" do
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_return(
            "failed"       => true,
            "finished"     => true,
            "started"      => true,
            "disks"        => [
              { "path" => src_disk_1.filename, "progress" => 23.0 },
              { "path" => src_disk_2.filename, "progress" => 0.0 }
            ],
            "pid"          => 5855,
            "return_code"  => 1,
            "disk_count"   => 2,
            "last_message" => {
              "message" => "virt-v2v failed somehow",
              "type"    => "error"
            }
          )
          task_1.get_conversion_state
          expect(task_1.options[:virtv2v_status]).to eq('failed')
          expect(task_1.options[:virtv2v_finished_on]).to eq(time_now.strftime('%Y-%m-%d %H:%M:%S'))
          expect(task_1.options[:virtv2v_message]).to eq('virt-v2v failed somehow')
        end

        it "updates disks progress" do
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_return(
            "started"    => true,
            "disks"      => [
              { "path" => src_disk_1.filename, "progress" => 100.0 },
              { "path" => src_disk_2.filename, "progress" => 50.0 }
            ],
            "pid"        => 5855,
            "disk_count" => 2
          )
          task_1.get_conversion_state
          expect(task_1.options[:virtv2v_disks]).to eq(
            [
              {"path" => src_disk_1.filename, "progress" => 100},
              {"path" => src_disk_2.filename, "progress" => 50}
            ]
          )
          expect(task_1.options[:virtv2v_status]).to eq('active')
        end

        it "sets disks progress to 100% when conversion is finished and successful" do
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_return(
            "finished"    => true,
            "started"     => true,
            "disks"       => [
              { "path" => src_disk_1.filename, "progress" => 100.0},
              { "path" => src_disk_2.filename, "progress" => 100.0}
            ],
            "pid"         => 5855,
            "return_code" => 0,
            "disk_count"  => 1,
            "vm_id"       => "01234567-89ab-cdef-0123-456789ab-cdef"
          )
          task_1.get_conversion_state
          expect(task_1.options[:virtv2v_disks]).to eq(
            [
              { :path => src_disk_1.filename, :size => src_disk_1.size, :percent => 100, :weight  => 50 },
              { :path => src_disk_2.filename, :size => src_disk_2.size, :percent => 100, :weight  => 50 }
            ]
          )
          expect(task_1.options[:virtv2v_status]).to eq('succeeded')
          expect(task_1.options[:virtv2v_finished_on]).to eq(time_now.utc.strftime('%Y-%m-%d %H:%M:%S'))
          expect(task_1.options[:virtv2v_message]).to be_nil
        end

        it "sets disks progress to 100% when conversion is finished and successful unless canceling" do
          task_1.canceling
          allow(conversion_host).to receive(:get_conversion_state).with(task_1.id).and_return(
            "finished"    => true,
            "started"     => true,
            "disks"       => [
              { "path" => src_disk_1.filename, "progress" => 100.0},
              { "path" => src_disk_2.filename, "progress" => 100.0}
            ],
            "pid"         => 5855,
            "return_code" => 0,
            "disk_count"  => 1
          )
          task_1.get_conversion_state
          expect(task_1.options[:virtv2v_disks]).to eq(
            [
              { :path => src_disk_1.filename, :size => src_disk_1.size, :percent => 12.0, :weight  => 50 },
              { :path => src_disk_2.filename, :size => src_disk_2.size, :percent => 0.0, :weight  => 50 }
            ]
          )
          expect(task_1.options[:virtv2v_finished_on]).to eq(time_now.utc.strftime('%Y-%m-%d %H:%M:%S'))
          expect(task_1.options[:virtv2v_message]).to be_nil
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
        let(:conversion_host) do
          FactoryBot.create(
            :conversion_host,
            :resource => FactoryBot.create(:host_redhat, :ext_management_system => redhat_ems)
          )
        end

        let(:mapping) do
          FactoryBot.create(:transformation_mapping).tap do |tm|
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_cluster,
                              :destination            => redhat_cluster,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_storage,
                              :destination            => redhat_storages.first,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_lans.first,
                              :destination            => redhat_lans.first,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_lans.last,
                              :destination            => redhat_lans.last,
                              :transformation_mapping => tm)
          end
        end

        before do
          task_1.conversion_host = conversion_host
        end

        it { expect(task_1.destination_cluster).to eq(redhat_cluster) }

        it_behaves_like "#virtv2v_disks"

        context "#network_mappings" do
          it "generates network_mappings hash" do
            expect(task_1.network_mappings).to eq(
              [
                { :source => src_lans.first.name, :destination => redhat_lans.first.name, :mac_address => src_nic_1.address, :ip_address => '10.0.1.1' },
                { :source => src_lans.last.name, :destination => redhat_lans.last.name, :mac_address => src_nic_2.address }
              ]
            )
          end
        end

        context "#prelight_check" do
          it "passes preflight check regardless of power_state" do
            src_host.authentications << host_auth
            allow(src_host).to receive(:authentication_status_ok?).and_return(true)
            src_vm_1.send(:power_state=, 'anything')
            expect(task_1.preflight_check).to eq(:status => 'Ok', :message => 'Preflight check is successful')
          end

          it "fails if a VM already exists in destination" do
            FactoryBot.create(:vm_redhat, :name => src_vm_1.name, :ext_management_system => redhat_ems, :ems_cluster => redhat_cluster)
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "A VM named '#{src_vm_1.name}' already exist in destination cluster")
          end

          it "fails preflight check if host has no credentials" do
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "No credentials configured for '#{src_host.name}'")
          end

          it "fails preflight check if host authentication failed" do
            src_host.authentications << host_auth
            allow(src_host).to receive(:authentication_status_ok?).and_return(false)
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "Invalid authentication for '#{src_host.name}': fake error")
          end
        end

        it_behaves_like "#get_conversion_state"

        context "transport method is vddk" do
          before do
            conversion_host.vddk_transport_supported = true
          end

          it "generates conversion options hash with host admin IP address" do
            expect(task_1.conversion_options).to eq(
              :vm_name              => src_vm_1.name,
              :vm_uuid              => src_vm_1.uid_ems,
              :conversion_host_uuid => conversion_host.resource.ems_ref,
              :transport_method     => 'vddk',
              :vmware_fingerprint   => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
              :vmware_uri           => "esx://esx_user@10.0.0.1/?no_verify=1",
              :vmware_password      => 'esx_passwd',
              :rhv_url              => "https://#{redhat_ems.hostname}/ovirt-engine/api",
              :rhv_cluster          => redhat_cluster.name,
              :rhv_storage          => redhat_storages.first.name,
              :rhv_password         => redhat_ems.authentication_password,
              :source_disks         => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings     => task_1.network_mappings,
              :install_drivers      => true,
              :insecure_connection  => true,
              :two_phase            => true,
              :warm                 => true,
              :daemonize            => false
            )
          end

          it "generates conversion options hash with host custom IP address" do
            src_host.miq_custom_set('TransformationIPAddress', '192.168.254.1')
            expect(task_1.conversion_options).to eq(
              :vm_name              => src_vm_1.name,
              :vm_uuid              => src_vm_1.uid_ems,
              :conversion_host_uuid => conversion_host.resource.ems_ref,
              :transport_method     => 'vddk',
              :vmware_fingerprint   => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
              :vmware_uri           => "esx://esx_user@192.168.254.1/?no_verify=1",
              :vmware_password      => 'esx_passwd',
              :rhv_url              => "https://#{redhat_ems.hostname}/ovirt-engine/api",
              :rhv_cluster          => redhat_cluster.name,
              :rhv_storage          => redhat_storages.first.name,
              :rhv_password         => redhat_ems.authentication_password,
              :source_disks         => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings     => task_1.network_mappings,
              :install_drivers      => true,
              :insecure_connection  => true,
              :two_phase            => true,
              :warm                 => true,
              :daemonize            => false
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
              :vm_name              => "ssh://root@10.0.0.1/vmfs/volumes/stockage%20r%C3%A9cent/#{src_vm_1.location}",
              :vm_uuid              => src_vm_1.uid_ems,
              :conversion_host_uuid => conversion_host.resource.ems_ref,
              :transport_method     => 'ssh',
              :rhv_url              => "https://#{redhat_ems.hostname}/ovirt-engine/api",
              :rhv_cluster          => redhat_cluster.name,
              :rhv_storage          => redhat_storages.first.name,
              :rhv_password         => redhat_ems.authentication_password,
              :source_disks         => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings     => task_1.network_mappings,
              :install_drivers      => true,
              :insecure_connection  => true,
              :daemonize            => false
            )
          end

          it "generates conversion options hash with host custom IP address" do
            src_host.miq_custom_set('TransformationIPAddress', '192.168.254.1')
            expect(task_1.conversion_options).to eq(
              :vm_name              => "ssh://root@192.168.254.1/vmfs/volumes/stockage%20r%C3%A9cent/#{src_vm_1.location}",
              :vm_uuid              => src_vm_1.uid_ems,
              :conversion_host_uuid => conversion_host.resource.ems_ref,
              :transport_method     => 'ssh',
              :rhv_url              => "https://#{redhat_ems.hostname}/ovirt-engine/api",
              :rhv_cluster          => redhat_cluster.name,
              :rhv_storage          => redhat_storages.first.name,
              :rhv_password         => redhat_ems.authentication_password,
              :source_disks         => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings     => task_1.network_mappings,
              :install_drivers      => true,
              :insecure_connection  => true,
              :daemonize            => false
            )
          end
        end
      end

      context 'destination is openstack' do
        let(:openstack_ems) { FactoryBot.create(:ems_openstack, :api_version => 'v3', :zone => FactoryBot.create(:zone)) }
        let(:openstack_cloud_tenant) { FactoryBot.create(:cloud_tenant, :name => 'fake tenant', :ext_management_system => openstack_ems) }
        let(:openstack_cloud_volume_type) { FactoryBot.create(:cloud_volume_type) }
        let(:openstack_cloud_networks) { FactoryBot.create_list(:cloud_network, 2, :cloud_tenant => openstack_cloud_tenant) }
        let(:openstack_flavor) { FactoryBot.create(:flavor) }
        let(:openstack_security_group) { FactoryBot.create(:security_group) }
        let(:conversion_host_vm) { FactoryBot.create(:vm_openstack, :ext_management_system => openstack_ems, :cloud_tenant => openstack_cloud_tenant) }
        let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => conversion_host_vm) }

        let(:mapping) do
          FactoryBot.create(:transformation_mapping).tap do |tm|
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_cluster,
                              :destination            => openstack_cloud_tenant,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_storage,
                              :destination            => openstack_cloud_volume_type,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_lans.first,
                              :destination            => openstack_cloud_networks.first,
                              :transformation_mapping => tm)
            FactoryBot.create(:transformation_mapping_item,
                              :source                 => src_lans.last,
                              :destination            => openstack_cloud_networks.last,
                              :transformation_mapping => tm)
          end
        end

        before do
          task_1.conversion_host = conversion_host
        end

        it { expect(task_1.destination_cluster).to eq(openstack_cloud_tenant) }

        it_behaves_like "#virtv2v_disks"

        context "#network_mappings" do
          it "generates network_mappings hash" do
            expect(task_1.network_mappings).to eq(
              [
                { :source => src_lans.first.name, :destination => openstack_cloud_networks.first.ems_ref, :mac_address => src_nic_1.address, :ip_address => '10.0.1.1' },
                { :source => src_lans.last.name, :destination => openstack_cloud_networks.last.ems_ref, :mac_address => src_nic_2.address }
              ]
            )
          end
        end

        context "preflight_check" do
          it "fails preflight check if src is power off" do
            src_host.authentications << host_auth
            allow(src_host).to receive(:authentication_status_ok?).and_return(true)
            src_vm_1.send(:power_state=, 'off')
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => 'OSP destination and source power_state is off')
          end

          it "fails if a VM already exists in destination" do
            FactoryBot.create(:vm_openstack, :name => src_vm_1.name, :ext_management_system => openstack_ems, :cloud_tenant => openstack_cloud_tenant)
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "A VM named '#{src_vm_1.name}' already exist in destination cloud tenant")
          end

          it "fails preflight check if host has no credentials" do
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "No credentials configured for '#{src_host.name}'")
          end

          it "fails preflight check if host authention failed" do
            src_host.authentications << host_auth
            allow(src_host).to receive(:authentication_status_ok?).and_return(false)
            expect(task_1.preflight_check).to eq(:status => 'Error', :message => "Invalid authentication for '#{src_host.name}': fake error")
          end
        end

        it_behaves_like "#get_conversion_state"

        context "transport method is vddk" do
          before do
            conversion_host.vddk_transport_supported = true
          end

          it "generates conversion options hash" do
            expect(task_1.conversion_options).to eq(
              :vm_name                    => src_vm_1.name,
              :vm_uuid                    => src_vm_1.uid_ems,
              :conversion_host_uuid       => conversion_host.ems_ref,
              :transport_method           => 'vddk',
              :vmware_fingerprint         => '01:23:45:67:89:ab:cd:ef:01:23:45:67:89:ab:cd:ef:01:23:45:67',
              :vmware_uri                 => "esx://esx_user@10.0.0.1/?no_verify=1",
              :vmware_password            => 'esx_passwd',
              :osp_environment            => {
                :os_auth_url             => URI::Generic.build(
                  :scheme => openstack_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                  :host   => openstack_ems.hostname,
                  :port   => openstack_ems.port,
                  :path   => '/v3'
                ).to_s,
                :os_identity_api_version => '3',
                :os_user_domain_name     => openstack_ems.uid_ems,
                :os_username             => openstack_ems.authentication_userid,
                :os_password             => openstack_ems.authentication_password,
                :os_project_name         => openstack_cloud_tenant.name
              },
              :osp_server_id              => conversion_host_vm.ems_ref,
              :osp_destination_project_id => openstack_cloud_tenant.ems_ref,
              :osp_volume_type_id         => openstack_cloud_volume_type.ems_ref,
              :osp_flavor_id              => openstack_flavor.ems_ref,
              :osp_security_groups_ids    => [openstack_security_group.ems_ref],
              :source_disks               => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings           => task_1.network_mappings,
              :two_phase                  => true,
              :warm                       => true,
              :daemonize                  => false
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
              :vm_name                    => "ssh://root@10.0.0.1/vmfs/volumes/stockage%20r%C3%A9cent/#{src_vm_1.location}",
              :vm_uuid                    => src_vm_1.uid_ems,
              :conversion_host_uuid       => conversion_host.ems_ref,
              :transport_method           => 'ssh',
              :osp_environment            => {
                :os_auth_url             => URI::Generic.build(
                  :scheme => openstack_ems.security_protocol == 'non-ssl' ? 'http' : 'https',
                  :host   => openstack_ems.hostname,
                  :port   => openstack_ems.port,
                  :path   => '/v3'
                ).to_s,
                :os_identity_api_version => '3',
                :os_user_domain_name     => openstack_ems.uid_ems,
                :os_username             => openstack_ems.authentication_userid,
                :os_password             => openstack_ems.authentication_password,
                :os_project_name         => openstack_cloud_tenant.name
              },
              :osp_server_id              => conversion_host_vm.ems_ref,
              :osp_destination_project_id => openstack_cloud_tenant.ems_ref,
              :osp_volume_type_id         => openstack_cloud_volume_type.ems_ref,
              :osp_flavor_id              => openstack_flavor.ems_ref,
              :osp_security_groups_ids    => [openstack_security_group.ems_ref],
              :source_disks               => [src_disk_1.filename, src_disk_2.filename],
              :network_mappings           => task_1.network_mappings,
              :daemonize                  => false
            )
          end
        end
      end
    end
  end
end
