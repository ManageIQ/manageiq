RSpec.describe InfraConversionJob, :v2v do
  let(:user)                  { FactoryBot.create(:user_with_group) }
  let(:user_admin)            { FactoryBot.create(:user_admin) }
  let(:group)                 { FactoryBot.create(:miq_group) }
  let(:zone)                  { FactoryBot.create(:zone) }
  let(:server)                { FactoryBot.create(:miq_server) }

  let(:ems_vmware)            { FactoryBot.create(:ems_vmware, :zone => zone) }
  let(:ems_cluster_vmware)    { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }
  let(:host_vmware)           { FactoryBot.create(:host, :ext_management_system => ems_vmware, :ems_cluster => ems_cluster_vmware) }
  let(:lan_vmware)            { FactoryBot.create(:lan) }
  let(:network_vmware)        { FactoryBot.create(:network, :ipaddress => nil) }
  let(:nic_vmware)            { FactoryBot.create(:guest_device_nic, :lan => lan_vmware, :network => network_vmware) }
  let(:hardware_vmware)       { FactoryBot.create(:hardware, :nics => [nic_vmware], :networks => [network_vmware]) }
  let(:vm_vmware) do
    FactoryBot.create(:vm_vmware,
                      :ext_management_system => ems_vmware,
                      :ems_cluster           => ems_cluster_vmware,
                      :host                  => host_vmware,
                      :hardware              => hardware_vmware,
                      :evm_owner             => user,
                      :miq_group             => group)
  end

  let(:ems_redhat)            { FactoryBot.create(:ems_redhat, :zone => zone) }
  let(:ems_cluster_redhat)    { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }
  let(:host_redhat)           { FactoryBot.create(:host, :ext_management_system => ems_redhat, :ems_cluster => ems_cluster_redhat) }
  let(:vm_redhat)             { FactoryBot.create(:vm_vmware, :ext_management_system => ems_redhat, :ems_cluster => ems_cluster_redhat, :host => host_redhat, :evm_owner => user_admin) }

  let(:embedded_ansible_auth) { FactoryBot.create(:embedded_ansible_credential) }
  let(:embedded_ansible_catalog_item_options) do
    {
      :name        => 'Test Migration Playbook',
      :description => 'Migration Playbook for testing purpose',
      :config_info => {
        :provision => {
          :credential_id => embedded_ansible_auth.id,
          :hosts         => 'localhost',
        },
      }
    }
  end
  let(:embedded_ansible_service_template) { ServiceTemplateAnsiblePlaybook.create_catalog_item(embedded_ansible_catalog_item_options, nil) }
  let(:embedded_ansible_service_request)  { FactoryBot.create(:service_template_provision_request, :source => embedded_ansible_service_template, :approval_state => 'approved', :requester => user) }

  let(:transformation_mapping) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => ems_cluster_vmware,
                        :destination            => ems_cluster_redhat,
                        :transformation_mapping => tm)
    end
  end

  let(:transformation_plan_catalog_item_options) do
    {
      :name        => 'Test Transformation Plan',
      :description => 'Transformation Plan for testing purpose',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => embedded_ansible_service_template.id,
        :post_service_id           => embedded_ansible_service_template.id,
        :actions                   => [
          {:vm_id => vm_vmware.id.to_s, :pre_service => true, :post_service => true},
        ],
      }
    }
  end
  let(:transformation_plan) { ServiceTemplateTransformationPlan.create_catalog_item(transformation_plan_catalog_item_options) }

  let(:request)         { FactoryBot.create(:service_template_transformation_plan_request, :source => transformation_plan) }
  let(:task)            { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :source => vm_vmware, :userid => user.userid) }
  let(:job_options)     { {:target_class => task.class.name, :target_id => task.id} }
  let(:job)             { described_class.create_job(job_options) }

  before do
    allow(MiqServer).to receive(:my_zone).and_return(zone.name)
    allow(MiqServer).to receive(:my_server).and_return(server)
  end

  context '.create_job' do
    it 'leaves job waiting to start' do
      job = described_class.create_job(job_options)
      expect(job.state).to eq('waiting_to_start')
    end
  end

  context '.target_vm' do
    it 'returns nil if no phase is set' do
      expect(job.target_vm).to be_nil
    end

    it 'returns migration_task.source if migration phase is "pre"' do
      task.update_options(:migration_phase => 'pre')
      task.reload
      expect(job.target_vm.id).to eq(vm_vmware.id)
    end

    it 'returns vm_redhat if migration phase is "post"' do
      task.update_options(:migration_phase => 'post')
      task.update!(:destination => vm_redhat)
      task.reload
      expect(job.target_vm.id).to eq(vm_redhat.id)
    end
  end

  context '.abort_conversion' do
    it 'updates task progress and signals :abort_virtv2v' do
      job.state = 'waiting_for_ip_address'
      Timecop.freeze(2019, 2, 6) do
        progress = {
          :current_state       => 'waiting_for_ip_address',
          :current_description => 'Waiting for IP address',
          :percent             => 3.5,
          :states              => {
            :waiting_for_ip_address     => {
              :description => 'Waiting for VM IP address',
              :state       => 'active',
              :status      => 'Ok',
              :started_on  => Time.now.utc - 10.minutes,
              :updated_on  => Time.now.utc - 5.minutes,
              :percent     => 10.0
            }
          },
          :status              => 'ok'
        }
        task.update_options(:progress => progress)
        expect(job).to receive(:queue_signal).once.ordered.with(:abort_virtv2v)
        job.abort_conversion('fake error', 'error')
        expect(task.reload.options[:progress]).to eq(
          :current_state       => 'waiting_for_ip_address',
          :current_description => 'Migration failed: fake error. Cancelling',
          :percent             => 3.5,
          :states              => {
            :waiting_for_ip_address     => {
              :description => 'Waiting for VM IP address',
              :state       => 'active',
              :status      => 'Ok',
              :started_on  => Time.now.utc - 10.minutes,
              :updated_on  => Time.now.utc - 5.minutes,
              :percent     => 10.0
            }
          },
          :status              => 'error'
        )
      end
    end

    it 'initiate waiting_to_start state, updates task progress and signals :abort_virtv2v' do
      job.state = 'waiting_to_start'
      expect(job).to receive(:queue_signal).once.ordered.with(:abort_virtv2v)
      job.abort_conversion('fake error', 'ok')
      expect(job.migration_task.reload.options[:progress]).to eq(
        :current_state       => 'waiting_to_start',
        :current_description => 'Migration failed: fake error. Cancelling',
        :percent             => 0.0,
        :states              => {:waiting_to_start => {}},
        :status              => 'ok'
      )
    end
  end

  context 'state hash methods' do
    before do
      job.state = 'running_migration_playbook'
      job.context[:retries_running_migration_playbook] = 288
      task.update_options(:migration_phase => 'pre')
    end

    context '.on_entry' do
      it 'initializes the state hash if it did not exist' do
        Timecop.freeze(2019, 2, 6) do
          expect(job.on_entry(nil, nil)).to eq(
            :description => 'Running pre-migration playbook',
            :state       => 'active',
            :status      => 'Ok',
            :started_on  => Time.now.utc,
            :percent     => 0.0
          )
        end
      end
    end

    context '.on_retry' do
      it 'uses ad-hoc percentage if no progress is provided' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 20.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end

      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 25.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, :percent => 25.0)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_exit' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :percent    => 100.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_exit(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_error' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :status     => 'Error',
            :updated_on => Time.now.utc
          }
          expect(job.on_error(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.update_migration_task_progress' do
      context 'on_entry' do
        it 'initializes the progress hash on entry if it does not exist' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'waiting_for_ip_address',
              :current_description => 'Waiting for VM IP address',
              :percent             => 2.0,
              :states              => {
                :waiting_for_ip_address => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                }
              }
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_entry)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 2.0,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc,
                  :percent     => 0.0
                }
              }
            )
          end
        end
      end

      context 'on_retry' do
        it 'updates the task progress hash on retry without a state progress hash' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 3.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 10.0,
                  :updated_on  => Time.now.utc - 30.seconds
                }
              }
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_retry)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 5.0,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 20.0,
                  :updated_on  => Time.now.utc
                }
              }
            )
          end
        end

        it 'updates the task progress hash on retry with a state progress hash' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 3.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 10.0,
                  :updated_on  => Time.now.utc - 30.seconds
                }
              }
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_retry, :percent => 30)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 6.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 30.0,
                  :updated_on  => Time.now.utc
                }
              }
            )
          end
        end

        it 'doesn\'t update the task progress hash if progress[:status] is "error"' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook failed: fake error',
              :percent             => 3.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'finished',
                  :status      => 'Error',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 10.0,
                  :updated_on  => Time.now.utc - 30.seconds
                }
              },
              :status              => 'error'
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_retry, :percent => 30)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook failed: fake error',
              :percent             => 3.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'finished',
                  :status      => 'Error',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 10.0,
                  :updated_on  => Time.now.utc - 30.seconds
                }
              },
              :status              => 'error'
            )
          end
        end
      end

      context 'on_exit and on_error' do
        it 'updates the task progress hash on exit' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 6.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 30.0,
                  :updated_on  => Time.now.utc
                }
              }
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_exit)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 17.0,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 100.0,
                  :updated_on  => Time.now.utc
                }
              }
            )
          end
        end

        it 'updates the task progress hash on error' do
          Timecop.freeze(2019, 2, 6) do
            progress = {
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 6.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'active',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 30.0,
                  :updated_on  => Time.now.utc
                }
              }
            }
            task.update_options(:progress => progress)
            job.update_migration_task_progress(:on_error)
            expect(task.reload.options[:progress]).to eq(
              :current_state       => 'running_migration_playbook',
              :current_description => 'Running pre-migration playbook',
              :percent             => 6.5,
              :states              => {
                :waiting_for_ip_address     => {
                  :description => 'Waiting for VM IP address',
                  :state       => 'finished',
                  :status      => 'Ok',
                  :started_on  => Time.now.utc - 10.minutes,
                  :updated_on  => Time.now.utc - 5.minutes,
                  :percent     => 100.0
                },
                :running_migration_playbook => {
                  :description => 'Running pre-migration playbook',
                  :state       => 'finished',
                  :status      => 'Error',
                  :started_on  => Time.now.utc - 1.minute,
                  :percent     => 30.0,
                  :updated_on  => Time.now.utc
                }
              }
            )
          end
        end
      end

      it 'aborts conversion if task cancel is requested' do
        task.cancel
        expect(job).to receive(:abort_conversion).once.ordered.with('Migration cancelation requested', 'ok').and_call_original
        expect(job).to receive(:queue_signal).once.ordered.with(:abort_virtv2v)
        job.update_migration_task_progress(:on_entry)
      end
    end
  end

  context 'state transitions' do
    %w[start start_precopying_disks poll_precopying_disks wait_for_ip_address run_migration_playbook poll_run_migration_playbook_complete shutdown_vm poll_shutdown_vm_complete transform_vm poll_transform_vm_complete inventory_refresh poll_inventory_refresh_complete apply_right_sizing restore_vm_attributes power_on_vm poll_power_on_vm_complete mark_vm_migrated abort_virtv2v poll_automate_state_machine finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w[start start_precopying_disks poll_precopying_disks wait_for_ip_address run_migration_playbook poll_run_migration_playbook_complete shutdown_vm poll_shutdown_vm_complete transform_vm poll_transform_vm_complete inventory_refresh poll_inventory_refresh_complete apply_right_sizing restore_vm_attributes power_on_vm poll_power_on_vm_complete mark_vm_migrated abort_virtv2v poll_automate_state_machine].each do |signal|
      shared_examples_for "doesn't allow #{signal} signal" do
        it signal.to_s do
          expect { job.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{job.state}/)
        end
      end
    end

    context 'waiting_to_start' do
      before do
        job.state = 'waiting_to_start'
      end

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'started' do
      before do
        job.state = 'started'
      end

      it_behaves_like 'allows start_precopying_disks signal'
      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'precopying_disks' do
      before do
        job.state = 'precopying_disks'
      end

      it_behaves_like 'allows poll_precopying_disks signal'
      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'waiting_for_ip_address' do
      before do
        job.state = 'waiting_for_ip_address'
      end

      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows run_migration_playbook signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'running_migration_playbook' do
      before do
        job.state = 'running_migration_playbook'
      end

      it_behaves_like 'allows poll_run_migration_playbook_complete signal'
      it_behaves_like 'allows shutdown_vm signal'
      it_behaves_like 'allows mark_vm_migrated signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
    end

    context 'shutting_down_vm' do
      before do
        job.state = 'shutting_down_vm'
      end

      it_behaves_like 'allows transform_vm signal'
      it_behaves_like 'allows poll_shutdown_vm_complete signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'transforming_vm' do
      before do
        job.state = 'transforming_vm'
      end

      it_behaves_like 'allows poll_transform_vm_complete signal'
      it_behaves_like 'allows inventory_refresh signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'waiting_for_inventory_refresh' do
      before do
        job.state = 'waiting_for_inventory_refresh'
      end

      it_behaves_like 'allows poll_inventory_refresh_complete signal'
      it_behaves_like 'allows apply_right_sizing signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow inventory_refresh signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'applying_right_sizing' do
      before do
        job.state = 'applying_right_sizing'
      end

      it_behaves_like 'allows restore_vm_attributes signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'restoring_vm_attributes' do
      before do
        job.state = 'restoring_vm_attributes'
      end

      it_behaves_like 'allows power_on_vm signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'powering_on_vm' do
      before do
        job.state = 'powering_on_vm'
      end

      it_behaves_like 'allows poll_power_on_vm_complete signal'
      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows mark_vm_migrated signal'
      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
    end

    context 'marking_vm_migrated' do
      before do
        job.state = 'marking_vm_migrated'
      end

      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
    end

    context 'canceling' do
      before do
        job.state = 'canceling'
      end

      it_behaves_like 'allows abort_virtv2v signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'aborting_virtv2v' do
      before do
        job.state = 'aborting_virtv2v'
      end

      it_behaves_like 'allows abort_virtv2v signal'
      it_behaves_like 'allows power_on_vm signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'running_in_automate' do
      before do
        job.state = 'running_in_automate'
      end

      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow start_precopying_disks signal'
      it_behaves_like 'doesn\'t allow poll_precopying_disks signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow shutdown_vm signal'
      it_behaves_like 'doesn\'t allow poll_shutdown_vm_complete signal'
      it_behaves_like 'doesn\'t allow transform_vm signal'
      it_behaves_like 'doesn\'t allow poll_transform_vm_complete signal'
      it_behaves_like 'doesn\'t allow poll_inventory_refresh_complete signal'
      it_behaves_like 'doesn\'t allow apply_right_sizing signal'
      it_behaves_like 'doesn\'t allow restore_vm_attributes signal'
      it_behaves_like 'doesn\'t allow power_on_vm signal'
      it_behaves_like 'doesn\'t allow mark_vm_migrated signal'
      it_behaves_like 'doesn\'t allow poll_power_on_vm_complete signal'
    end
  end

  context 'transition methods' do
    context '#start' do
      it 'signals wait_for_ip_address when preflight_check passes and is cold migration' do
        allow(job.migration_task).to receive(:warm_migration?).and_return(false)
        expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
        job.signal(:start)
        expect(task.reload.state).to eq('migrate')
      end

      it 'signals start_precopying_disks when preflight_check passes and is warm migration' do
        allow(job.migration_task).to receive(:warm_migration?).and_return(true)
        expect(job).to receive(:queue_signal).with(:start_precopying_disks)
        job.signal(:start)
        expect(task.reload.state).to eq('migrate')
      end
    end

    context '#start_precopying_disks' do
      before do
        job.state = 'started'
      end

      it 'starts conversion' do
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job.migration_task).to receive(:run_conversion)
          expect(job).to receive(:queue_signal).with(:poll_precopying_disks, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:start_precopying_disks)
        end
      end
    end

    context '#poll_precopying_disks' do
      before do
        job.state = 'precopying_disks'
        allow(job.migration_task).to receive(:get_conversion_state)
      end

      it 'abort_conversion when precopying_disks times out' do
        job.context[:retries_precopying_disks] = 8640
        expect(job).to receive(:abort_conversion).with('Precopying disks timed out', 'error')
        job.signal(:poll_precopying_disks)
      end

      it 'retries if cutover datetime is not defined or has not been reached' do
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
          expect(job).to receive(:queue_signal).with(:poll_precopying_disks, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:poll_precopying_disks)
        end
      end

      it 'exits if cutover datetime is defined and has been reached' do
        Timecop.freeze(2019, 2, 6) do
          request.options[:cutover_datetime] = Time.now.utc - 1.minute
          request.save!
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
          job.signal(:poll_precopying_disks)
        end
      end
    end

    context '#wait_for_ip_address' do
      before do
        task.update_options(:migration_phase => 'pre', :source_vm_ipaddresses => ['10.0.0.1'])
        job.state = 'started'
      end

      it 'abort_conversion when waiting_on_ip_address times out' do
        job.context[:retries_waiting_for_ip_address] = 240
        expect(job).to receive(:abort_conversion).with('Waiting for IP address timed out', 'error')
        job.signal(:wait_for_ip_address)
      end

      it 'exits if no playbook is expected to run' do
        allow(job.migration_task).to receive(:pre_ansible_playbook_service_template).and_return(nil)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:run_migration_playbook)
        job.signal(:wait_for_ip_address)
      end

      it 'exits if VM is powered off' do
        vm_vmware.update!(:raw_power_state => 'poweredOff')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:run_migration_playbook)
        job.signal(:wait_for_ip_address)
      end

      it 'exits if VM is powered on has an IP address' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        network_vmware.update!(:ipaddress => '10.0.0.1')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:run_migration_playbook)
        job.signal(:wait_for_ip_address)
      end

      it 'retries if VM is powered on and does not have an IP address' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
        expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
        job.signal(:wait_for_ip_address)
      end
    end

    context '#run_migration_playbook' do
      before do
        job.state = 'waiting_for_ip_address'
      end

      context "migration_phase is 'pre'" do
        before do
          task.update_options(:migration_phase => 'pre')
        end

        it "aborts in case of failure" do
          allow(job.migration_task).to receive(:pre_ansible_playbook_service_template).and_raise('Fake error message')
          expect(job).to receive(:abort_conversion).with('Fake error message', 'error')
          job.signal(:run_migration_playbook)
        end

        context 'without a service template matching the embedded ansible service template id' do
          it 'does not request service template provisioning' do
            embedded_ansible_service_template.delete
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
            expect(job).to receive(:queue_signal).with(:shutdown_vm)
            job.signal(:run_migration_playbook)
          end
        end

        context 'with a service template matching the embedded ansible service template id' do
          it 'creates a service template provision request' do
            Timecop.freeze(2019, 2, 6) do
              expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
              expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
              expect(job).to receive(:queue_signal).with(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
              job.signal(:run_migration_playbook)
              service_request = ServiceTemplateProvisionRequest.find(task.reload.options["#{task.options[:migration_phase]}_migration_playbook_service_request_id".to_sym])
              expect(service_request).to have_attributes(
                :description => "Provisioning Service [#{embedded_ansible_service_template.name}] from [#{embedded_ansible_service_template.name}]",
                :state       => 'pending',
                :status      => 'Ok',
                :userid      => user.userid
              )
            end
          end
        end
      end

      context "migration_phase is 'post'" do
        before do
          task.update_options(:migration_phase => 'post')
        end

        it "exits to next state in case of failure" do
          allow(job.migration_task).to receive(:pre_ansible_playbook_service_template).and_raise('Fake error message')
          expect(job).to receive(:queue_signal).with(:mark_vm_migrated)
          job.signal(:run_migration_playbook)
        end
      end
    end

    context '#poll_run_migration_playbook_complete' do
      before do
        job.state = 'running_migration_playbook'
        embedded_ansible_service = FactoryBot.create(:service_ansible_playbook)
        FactoryBot.create(:service_template_provision_task, :miq_request => embedded_ansible_service_request, :destination => embedded_ansible_service, :userid => user.userid)
        FactoryBot.create(:service_resource, :resource => FactoryBot.create(:embedded_ansible_job), :service => embedded_ansible_service)
      end

      context "migration_phase is 'pre'" do
        before do
          task.update_options(:migration_phase => 'pre', :pre_migration_playbook_service_request_id => embedded_ansible_service_request.id)
        end

        it 'abort_conversion when running_migration_playbook times out' do
          job.context[:retries_running_migration_playbook] = 1440
          expect(job).to receive(:abort_conversion).with('Running migration playbook timed out', 'error')
          job.signal(:poll_run_migration_playbook_complete)
        end

        it 'retries if service request is not finished' do
          embedded_ansible_service_request.update!(:request_state => 'active')
          Timecop.freeze(2019, 2, 6) do
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
            expect(job).to receive(:queue_signal).with(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
            job.signal(:poll_run_migration_playbook_complete)
          end
        end

        it 'exits if service request is finished and its status is Ok' do
          embedded_ansible_service_request.update!(:request_state => 'finished', :status => 'Ok')
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job).to receive(:queue_signal).with(:shutdown_vm)
          job.signal(:poll_run_migration_playbook_complete)
        end

        it 'fails if service request is finished and migration_phase is "pre" and its status is Error' do
          embedded_ansible_service_request.update!(:state => 'finished', :status => 'Error')
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
          expect(job).to receive(:abort_conversion).with('Ansible playbook has failed (migration_phase=pre)', 'error')
          job.signal(:poll_run_migration_playbook_complete)
        end
      end

      context "migration_phase is 'post'" do
        before do
          task.update_options(:migration_phase => 'post', :post_migration_playbook_service_request_id => embedded_ansible_service_request.id)
        end

        it "exits to next state in case of success" do
          embedded_ansible_service_request.update!(:request_state => 'finished', :status => 'Ok')
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job).to receive(:queue_signal).with(:mark_vm_migrated)
          job.signal(:poll_run_migration_playbook_complete)
        end

        it "exits to next state in case of failure" do
          allow(ServiceTemplateProvisionRequest).to receive(:find).and_raise('Fake error message')
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
          expect(job).to receive(:queue_signal).with(:mark_vm_migrated)
          job.signal(:poll_run_migration_playbook_complete)
        end
      end
    end

    context '#shutdown_vm' do
      before do
        task.update_options(:migration_phase => 'pre')
        job.state = 'running_migration_playbook'
      end

      it 'exits if VM is already off' do
        vm_vmware.update!(:raw_power_state => 'poweredOff')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:transform_vm)
        job.signal(:shutdown_vm)
      end

      it 'sends shutdown request to VM if VM supports shutdown_guest' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job.migration_task.source).to receive(:shutdown_guest)
          expect(job).to receive(:queue_signal).with(:poll_shutdown_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:shutdown_vm)
        end
      end

      it 'sends stop request to VM if VM does not support shutdown_guest' do
        vm_vmware.update!(:raw_power_state => 'unknown')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job.migration_task.source).to receive(:stop)
          expect(job).to receive(:queue_signal).with(:poll_shutdown_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:shutdown_vm)
        end
      end
    end

    context '#poll_shutdown_vm_complete' do
      before do
        task.update_options(:migration_phase => 'pre')
        job.state = 'shutting_down_vm'
      end

      it 'abort_conversion when shutting_down_vm times out' do
        job.context[:retries_shutting_down_vm] = 60
        expect(job).to receive(:abort_conversion).with('Shutting down VM timed out', 'error')
        job.signal(:poll_shutdown_vm_complete)
      end

      it 'retries if VM is not off' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
          expect(job).to receive(:queue_signal).with(:poll_shutdown_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:poll_shutdown_vm_complete)
        end
      end

      it 'exits if VM is off' do
        vm_vmware.update!(:raw_power_state => 'poweredOff')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:transform_vm)
        job.signal(:poll_shutdown_vm_complete)
      end
    end

    context '#transform_vm' do
      before do
        task.update_options(:migration_phase => 'pre', :virtv2v_wrapper => { 'cutover_file' => '/tmp/cutover' })
        job.state = 'shutting_down_vm'
      end

      it 'sends run_conversion and cutover to migration task and exits when cold migration' do
        allow(job.migration_task).to receive(:warm_migration?).and_return(false)
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job.migration_task).to receive(:run_conversion)
          expect(job.migration_task).to receive(:cutover)
          expect(job).to receive(:queue_signal).with(:poll_transform_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:transform_vm)
        end
      end

      it 'sends cutover to migration task and exits when warm migration' do
        allow(job.migration_task).to receive(:warm_migration?).and_return(true)
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job.migration_task).to receive(:cutover)
          expect(job).to receive(:queue_signal).with(:poll_transform_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:transform_vm)
        end
      end
    end

    context '#poll_transform_vm_complete' do
      before do
        job.state = 'transforming_vm'
        allow(job.migration_task).to receive(:get_conversion_state)
      end

      it 'abort_conversion when shutting_down_vm times out' do
        job.context[:retries_transforming_vm] = 5760
        expect(job).to receive(:abort_conversion).with('Converting disks timed out', 'error')
        job.signal(:poll_transform_vm_complete)
      end

      context 'virt-v2v has not started conversion' do
        let(:virtv2v_disks) do
          [
            { :path => '[datastore] test_vm/test_vm.vmdk', :size => 1_234_567, :percent => 0, :weight => 25 },
            { :path => '[datastore] test_vm/test_vm-2.vmdk', :size => 3_703_701, :percent => 0, :weight => 75 }
          ]
        end

        it 'returns a message stating conversion has not started' do
          task.update_options(:virtv2v_status => 'active', :virtv2v_disks => virtv2v_disks)
          Timecop.freeze(2019, 2, 6) do
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_call_original
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry, :message => 'Disk transformation is initializing.', :percent => 1).and_call_original
            expect(job).to receive(:queue_signal).with(:poll_transform_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
            job.signal(:poll_transform_vm_complete)
            expect(task.reload.options[:progress][:states][job.state.to_sym]).to include(
              :message => 'Disk transformation is initializing.',
              :percent => 1
            )
          end
        end
      end

      context "conversion is still running" do
        let(:virtv2v_disks) do
          [
            { :path => '[datastore] test_vm/test_vm.vmdk', :size => 1_234_567, :percent => 100, :weight => 25 },
            { :path => '[datastore] test_vm/test_vm-2.vmdk', :size => 3_703_701, :percent => 25, :weight => 75 }
          ]
        end

        it "updates message and percentage, and retries if conversion is not finished" do
          task.update_options(:virtv2v_status => 'active', :virtv2v_disks => virtv2v_disks)
          Timecop.freeze(2019, 2, 6) do
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_call_original
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry, :message => 'Converting disk 2 / 2 [43.75%].', :percent => 43.75).and_call_original
            expect(job).to receive(:queue_signal).with(:poll_transform_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
            job.signal(:poll_transform_vm_complete)
            expect(task.reload.options[:progress][:states][job.state.to_sym]).to include(
              :message => 'Converting disk 2 / 2 [43.75%].',
              :percent => 43.75
            )
          end
        end

        it "aborts if conversion failed" do
          task.update_options(:virtv2v_status => 'failed', :virtv2v_message => 'virt-v2v failed for some reason')
          expect(job).to receive(:abort_conversion).with('virt-v2v failed for some reason', 'error').and_call_original
          job.signal(:poll_transform_vm_complete)
        end

        it "exits if conversion succeeded" do
          task.update_options(:virtv2v_status => 'succeeded')
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_call_original
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit).and_call_original
          expect(job).to receive(:queue_signal).with(:inventory_refresh)
          job.signal(:poll_transform_vm_complete)
          expect(task.reload.options[:progress][:states][job.state.to_sym]).to include(:percent => 100.0)
        end
      end
    end
  end

  context '#inventory_refresh' do
    let(:target) { double(InventoryRefresh::TargetCollection) }

    before do
      job.state = 'transforming_vm'
      task.update_options(:destination_vm_uuid => '01234567-89ab-cdef-0123-456789ab-cdef')
    end

    it "aborts if conversion failed" do
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_raise('Fake error message')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
      expect(job).to receive(:queue_signal).with(:poll_inventory_refresh_complete)
      job.signal(:inventory_refresh)
    end

    it "exits after triggering targeted refresh succeeded" do
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_call_original
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit).and_call_original
        allow(InventoryRefresh::Target).to receive(:new).with(
          :association => :vms,
          :manager     => ems_redhat,
          :manager_ref => {:ems_ref => '/api/vms/01234567-89ab-cdef-0123-456789ab-cdef'}
        ).and_return(target)
        expect(EmsRefresh).to receive(:queue_refresh).with(target)
        expect(job).to receive(:queue_signal).with(:poll_inventory_refresh_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
        job.signal(:inventory_refresh)
      end
    end
  end

  context '#poll_inventory_refresh_complete' do
    before do
      job.state = 'waiting_for_inventory_refresh'
    end

    it 'abort_conversion when waiting_for_inventory_refresh times out' do
      job.context[:retries_waiting_for_inventory_refresh] = 240
      expect(job).to receive(:abort_conversion).with('Identify destination VM timed out', 'error')
      job.signal(:poll_inventory_refresh_complete)
    end

    it 'retry when destination VM is not in the inventory' do
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
        expect(job).to receive(:queue_signal).with(:poll_inventory_refresh_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
        job.signal(:poll_inventory_refresh_complete)
      end
    end

    it 'to finish when migration_task.state is finished' do
      allow(Vm).to receive(:find_by).with(:name => task.source.name, :ems_id => task.destination_ems.id).and_return(vm_redhat)
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry).and_call_original
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit).and_call_original
        expect(job).to receive(:queue_signal).with(:apply_right_sizing)
        job.signal(:poll_inventory_refresh_complete)
        expect(job.migration_task.destination.id).to eq(vm_redhat.id)
      end
    end
  end

  context '#apply_right_sizing' do
    before do
      job.state = 'waiting_for_inventory_refresh'
      task.update!(:destination => vm_redhat)
    end

    it "exits to next state in case of failure" do
      allow(job.migration_task).to receive(:cpu_right_sizing_mode).and_raise('Fake error message')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
      expect(job).to receive(:queue_signal).with(:restore_vm_attributes)
      job.signal(:apply_right_sizing)
    end

    context 'without right_sizing mode' do
      before do
        allow(job.migration_task).to receive(:cpu_right_sizing_mode).and_return(nil)
        allow(job.migration_task).to receive(:memory_right_sizing_mode).and_return(nil)
      end

      it 'exits if no right-sizing is requested' do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:restore_vm_attributes)
        job.signal(:apply_right_sizing)
      end
    end

    context 'with right_sizing_mode' do
      before do
        allow(job.migration_task).to receive(:cpu_right_sizing_mode).and_return(:aggressive)
        allow(job.migration_task).to receive(:memory_right_sizing_mode).and_return(:conservative)
        allow(job.migration_task.source).to receive(:aggressive_recommended_vcpus).and_return(1)
        allow(job.migration_task.source).to receive(:conservative_recommended_mem).and_return(1024)
      end

      it 'applies right-sizing if mode is set' do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job.migration_task.destination).to receive(:set_number_of_cpus).with(1)
        expect(job.migration_task.destination).to receive(:set_memory).with(1024)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:restore_vm_attributes)
        job.signal(:apply_right_sizing)
      end
    end
  end

  context '#restore_vm_attributes' do
    let(:service)               { FactoryBot.create(:service) }
    let(:parent_classification) { FactoryBot.create(:classification, :name => 'environment', :description => 'Environment') }
    let(:classification)        { FactoryBot.create(:classification, :name => 'prod', :description => 'Production', :parent => parent_classication) }

    before do
      job.state = 'applying_right_sizing'
      task.update!(:destination => vm_redhat)
    end

    it "exits to next state in case of failure" do
      allow(job.migration_task.source).to receive(:service).and_raise('Fake error message')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
      expect(job).to receive(:queue_signal).with(:power_on_vm)
      job.signal(:restore_vm_attributes)
    end

    it 'restore VM attributes' do
      Timecop.freeze(2019, 2, 6) do
        vm_vmware.add_to_service(service)
        vm_vmware.tag_with('test', :ns => '/managed', :cat => 'folder_path_spec')
        vm_vmware.tag_with('prod', :ns => '/managed', :cat => 'environment')
        vm_vmware.miq_custom_set('attr', 'value')
        vm_vmware.update!(:retires_on => Time.now.utc + 1.day)
        vm_vmware.update!(:retirement_warn => 7)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:power_on_vm)
        job.signal(:restore_vm_attributes)
        vm_redhat.reload
        expect(vm_vmware.service).to be_nil
        expect(vm_redhat.service.id).to eq(service.id)
        expect(vm_redhat.tags).to eq(['/managed/environment/prod'])
        expect(vm_redhat.miq_custom_get('attr')).to eq('value')
        expect(vm_redhat.evm_owner.id).to eq(user.id)
        expect(vm_redhat.miq_group.id).to eq(group.id)
        expect(vm_redhat.retires_on).to eq(Time.now.utc + 1.day)
        expect(vm_redhat.retirement_warn).to eq(7)
      end
    end
  end

  context '#restore_vm_attributes' do
    let(:service)               { FactoryBot.create(:service) }
    let(:parent_classification) { FactoryBot.create(:classification, :name => 'environment', :description => 'Environment') }
    let(:classification)        { FactoryBot.create(:classification, :name => 'prod', :description => 'Production', :parent => parent_classication) }

    before do
      job.state = 'applying_right_sizing'
      task.update!(:destination => vm_redhat)
    end

    it "exits to next state in case of failure" do
      allow(job.migration_task.source).to receive(:service).and_raise('Fake error message')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
      expect(job).to receive(:queue_signal).with(:power_on_vm)
      job.signal(:restore_vm_attributes)
    end

    it 'restore VM attributes' do
      Timecop.freeze(2019, 2, 6) do
        vm_vmware.add_to_service(service)
        vm_vmware.tag_with('test', :ns => '/managed', :cat => 'folder_path_spec')
        vm_vmware.tag_with('prod', :ns => '/managed', :cat => 'environment')
        vm_vmware.miq_custom_set('attr', 'value')
        vm_vmware.update!(:retires_on => Time.now.utc + 1.day)
        vm_vmware.update!(:retirement_warn => 7)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:power_on_vm)
        job.signal(:restore_vm_attributes)
        vm_redhat.reload
        expect(vm_vmware.service).to be_nil
        expect(vm_redhat.service.id).to eq(service.id)
        expect(vm_redhat.tags).to eq(['/managed/environment/prod'])
        expect(vm_redhat.miq_custom_get('attr')).to eq('value')
        expect(vm_redhat.evm_owner.id).to eq(user.id)
        expect(vm_redhat.miq_group.id).to eq(group.id)
        expect(vm_redhat.retires_on).to eq(Time.now.utc + 1.day)
        expect(vm_redhat.retirement_warn).to eq(7)
      end
    end
  end

  context '#power_on_vm' do
    before do
      job.state = 'restoring_vm_attributes'
      task.update_options(:migration_phase => 'post')
      task.update!(:destination => vm_redhat)
    end

    it 'exits if VM is already on' do
      vm_redhat.update!(:raw_power_state => 'poweredOn')
      task.update_options(:source_vm_power_state => 'on')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
      expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
      job.signal(:power_on_vm)
    end

    it "exits if source VM power state was not 'on'" do
      vm_redhat.update!(:raw_power_state => 'poweredOff')
      task.update_options(:source_vm_power_state => 'off')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
      expect(job).to receive(:queue_signal).with(:mark_vm_migrated)
      job.signal(:power_on_vm)
    end

    it 'sends start request to VM if VM is off' do
      vm_redhat.update!(:raw_power_state => 'poweredOff')
      task.update_options(:source_vm_power_state => 'on')
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job.migration_task.destination).to receive(:start)
        expect(job).to receive(:queue_signal).with(:poll_power_on_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
        job.signal(:power_on_vm)
      end
    end
  end

  context '#poll_power_on_vm_complete' do
    before do
      job.state = 'powering_on_vm'
      task.update_options(:migration_phase => 'post')
      task.update!(:destination => vm_redhat)
    end

    it "exits to next state in case of failure" do
      job.context[:retries_powering_on_vm] = 60
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
      expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
      job.signal(:poll_power_on_vm_complete)
      expect(task.reload.options[:workflow_runner]).to eq('automate')
    end

    it 'retries if VM is not on' do
      vm_redhat.update!(:raw_power_state => 'poweredOff')
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
        expect(job).to receive(:queue_signal).with(:poll_power_on_vm_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
        job.signal(:poll_power_on_vm_complete)
      end
    end

    it 'exits if VM is on' do
      vm_redhat.update!(:raw_power_state => 'poweredOn')
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
      expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
      expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
      job.signal(:poll_power_on_vm_complete)
    end
  end

  context '#abort_virtv2v' do
    before do
      job.state = 'aborting_virtv2v'
      allow(job.migration_task).to receive(:get_conversion_state)
    end

    context 'virt-v2v is not running' do
      before do
        task.update_options(:virtv2v_finished_on => Time.now.utc - 1.minute)
      end

      it 'exits to next state' do
        expect(job).to receive(:queue_signal).with(:power_on_vm)
        job.abort_virtv2v
      end
    end

    context 'virt-v2v is running' do
      before do
        job.migration_task.update_options(:virtv2v_started_on => Time.now.utc - 2.hours, :virtv2v_wrapper => {:key => 'value'})
      end

      it 'sends KILL signal to virt-v2v when aborting_virtv2v times out' do
        job.context[:retries_aborting_virtv2v] = 4
        expect(job.migration_task).to receive(:kill_virtv2v).with('KILL')
        expect(job).to receive(:queue_signal).with(:power_on_vm)
        job.abort_virtv2v
      end

      it 'sends TERM signal and retries to virt-v2v when entering state for the first time' do
        Timecop.freeze(2019, 2, 6) do
          expect(job.migration_task).to receive(:kill_virtv2v).with('TERM')
          expect(job).to receive(:queue_signal).with(:abort_virtv2v, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.abort_virtv2v
        end
      end

      it 'retries if not entering the state for the first time' do
        Timecop.freeze(2019, 2, 6) do
          job.context[:retries_aborting_virtv2v] = 1
          expect(job).to receive(:queue_signal).with(:abort_virtv2v, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.abort_virtv2v
        end
      end
    end
  end

  context '#mark_vm_migrated' do
    before do
      job.state = 'running_migration_playbook'
    end

    it 'calls task.mark_vm_migrated and hands over to automate' do
      expect(job.migration_task).to receive(:mark_vm_migrated).and_call_original
      expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
      job.mark_vm_migrated
      expect(task.reload.options[:workflow_runner]).to eq('automate')
      expect(vm_vmware.reload.is_tagged_with?('/transformation_status/migrated', :ns => '/managed')).to be_truthy
    end
  end

  context '#poll_automate_state_machine' do
    before do
      job.state = 'running_in_automate'
    end

    it 'abort_conversion when running_in_automate times out' do
      job.context[:retries_running_in_automate] = 8640
      expect(job).to receive(:abort_conversion).with('Polling Automate state machine timed out', 'error')
      job.signal(:poll_automate_state_machine)
    end

    it 'to poll_automate_state_machine when migration_task.state is not finished' do
      task.update!(:state => 'migrate')
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:queue_signal).with(:poll_automate_state_machine, :deliver_on => Time.now.utc + job.state_retry_interval)
        job.signal(:poll_automate_state_machine)
      end
    end

    it 'to finish when migration_task.state is finished' do
      task.update!(:state => 'finished', :status => 'Ok')
      Timecop.freeze(2019, 2, 6) do
        expect(job).to receive(:queue_signal).with(:finish)
        job.signal(:poll_automate_state_machine)
        expect(job.status).to eq(task.status)
      end
    end
  end
end
