require 'recursive-open-struct'

RSpec.describe MiqServer::WorkerManagement::Kubernetes do
  let(:server)          { FactoryBot.create(:miq_server_in_default_zone).tap { |s| EvmSpecHelper.stub_as_local_server(s) } }
  let(:orchestrator)    { double("ContainerOrchestrator") }
  let(:deployment_name) { '1-generic-79bb8b8bb5-8ggbg' }
  let(:pod_label)       { '1-generic' }

  before do
    allow(MiqServer::WorkerManagement).to receive(:podified?).and_return(true)
    allow(server.worker_manager).to receive(:orchestrator).and_return(orchestrator)
  end

  after do
    server.worker_manager.current_pods.clear
    server.worker_manager.current_deployments.clear
  end

  it "#current_pods initialized" do
    expect(server.worker_manager.current_pods).to_not be_nil
  end

  it ".current_pods initialized" do
    expect(server.worker_manager.class.current_pods).to_not be_nil
  end

  it ".current_pods and #current_pods share the same hash" do
    expect(server.worker_manager.class.current_pods.object_id).to eql(server.worker_manager.current_pods.object_id)
    server.worker_manager.current_pods[:a] = :b
    expect(server.worker_manager.class.current_pods[:a]).to eql(:b)
  end

  context "#ensure_kube_monitors_started" do
    it "calls start_kube_monitor if nil monitor thread" do
      expect(server.worker_manager).to receive(:start_kube_monitor).once.with(:deployments)
      expect(server.worker_manager).to receive(:start_kube_monitor).once.with(:pods)

      server.worker_manager.deployments_monitor_thread = nil
      server.worker_manager.pods_monitor_thread = nil
      server.worker_manager.send(:ensure_kube_monitors_started)
    end

    it "calls start_kube_monitor if monitor thread terminated normally" do
      expect(server.worker_manager).to receive(:start_kube_monitor).twice
      thread = double(:alive? => false, :status => false)
      expect(thread).to receive(:join).never

      server.worker_manager.deployments_monitor_thread = thread
      server.worker_manager.pods_monitor_thread = thread
      server.worker_manager.send(:ensure_kube_monitors_started)
    end

    it "joins a dead thread with an exception before calling start_kube_monitor" do
      expect(server.worker_manager).to receive(:start_kube_monitor).twice
      thread = double
      expect(thread).to receive(:alive?).twice.and_return(false)
      expect(thread).to receive(:status).twice.and_return(nil)
      expect(thread).to receive(:join).twice

      server.worker_manager.deployments_monitor_thread = thread
      server.worker_manager.pods_monitor_thread = thread
      server.worker_manager.send(:ensure_kube_monitors_started)
    end
  end

  context "#delete_failed_deployments" do
    let(:current_pods) do
      stats = Concurrent::Hash.new
      stats[:last_state_terminated] = false
      stats[:container_restarts] = 0
      stats[:label_name] = pod_label

      h = Concurrent::Hash.new
      h['1-generic-79bb8b8bb5-8ggbg'] = stats
      h
    end

    before do
      allow(server.worker_manager).to receive(:ensure_kube_monitors_started)
    end

    context "with no deployments" do
      it "doesn't call delete_deployment" do
        allow(server.worker_manager).to receive(:current_pods).and_return(Concurrent::Hash.new)
        expect(orchestrator).to receive(:delete_deployment).never
        server.worker_manager.cleanup_failed_workers
      end
    end

    context "with 1 running deployment" do
      it "doesn't call delete_deployment" do
        allow(server.worker_manager).to receive(:current_pods).and_return(current_pods)
        expect(orchestrator).to receive(:delete_deployment).never
        server.worker_manager.cleanup_failed_workers
      end
    end

    context "with a failed deployment" do
      before do
        current_pods[deployment_name][:last_state_terminated] = true
        current_pods[deployment_name][:container_restarts] = 100
      end

      it "calls delete_deployment with pod name" do
        allow(server.worker_manager).to receive(:current_pods).and_return(current_pods)
        expect(orchestrator).to receive(:delete_deployment).with(pod_label)
        server.worker_manager.cleanup_failed_workers
      end

      it "calls delete_deployment only once for a deployment with 2 failed pods" do
        # duplicate the pod information for a different pod name in the same deployment
        current_pods['1-generic-11aa1a1aa1-1aaaa'] = current_pods[deployment_name].dup

        allow(server.worker_manager).to receive(:current_pods).and_return(current_pods)
        expect(orchestrator).to receive(:delete_deployment).with(pod_label).once
        server.worker_manager.cleanup_failed_workers
      end
    end
  end

  context "#sync_from_system" do
    context "#ensure_kube_monitors_started" do
      it "podified, ensures pod monitor started and orphaned rows are removed" do
        expect(server.worker_manager).to receive(:ensure_kube_monitors_started)
        expect(server.worker_manager).to receive(:cleanup_orphaned_worker_rows)
        server.worker_manager.sync_from_system
      end
    end
  end

  context "#cleanup_orphaned_worker_rows" do
    context "podified" do
      let(:server2) { EvmSpecHelper.remote_miq_server }
      let(:worker) do
        FactoryBot.create(:miq_worker, :type => "MiqGenericWorker", :miq_server => server, :last_heartbeat => 5.minutes.ago)
      end

      before do
        server.worker_manager.current_pods = {"1-generic-active" => {}}
      end

      after do
        server.worker_manager.current_pods.clear
      end

      it "removes this server's orphaned rows" do
        worker.update(:system_uid => "1-generic-orphan")
        FactoryBot.create(:miq_worker, :type => "MiqGenericWorker", :miq_server => server, :system_uid => "1-generic-active")
        server.worker_manager.cleanup_orphaned_worker_rows
        expect(MiqWorker.count).to eq(1)
      end

      it "skips orphaned rows for other servers" do
        worker.update(:miq_server => server2, :system_uid => "1-generic-orphan")
        FactoryBot.create(:miq_worker, :type => "MiqGenericWorker", :miq_server => server2, :system_uid => "1-generic-active")
        server.worker_manager.cleanup_orphaned_worker_rows
        expect(MiqWorker.count).to eq(2)
      end
    end
  end

  context "#save_deployment(private)" do
    let(:pod_name) { "1-generic" }
    let(:fake_deployment_data) do
      RecursiveOpenStruct.new(
        :metadata => {
          :name => pod_name
        },
        :spec => {
          :replicas => 2,
          :template => {
            :spec => {
              :containers => [{:name => pod_name}]
            }
          }
        },
        :status => {
          :readyReplicas => 2
        }
      )
    end

    it "saves replicas" do
      server.worker_manager.send(:save_deployment, fake_deployment_data)
      expect(server.worker_manager.current_deployments[pod_name].fetch_path(:spec, :replicas)).to eq(2)
    end

    it "saves containers" do
      server.worker_manager.send(:save_deployment, fake_deployment_data)
      expect(server.worker_manager.current_deployments[pod_name].fetch_path(:spec, :template, :spec, :containers).first[:name]).to eq(pod_name)
    end

    it "discards other keys" do
      server.worker_manager.send(:save_deployment, fake_deployment_data)
      expect(server.worker_manager.current_deployments[pod_name].keys).to eq([:spec])
    end

    it "updates existing saved deployment" do
      server.worker_manager.send(:save_deployment, fake_deployment_data)
      fake_deployment_data.spec.replicas = 5
      server.worker_manager.send(:save_deployment, fake_deployment_data)
      expect(server.worker_manager.current_deployments[pod_name].fetch_path(:spec, :replicas)).to eq(5)
    end
  end

  context "#collect_initial(private)" do
    let(:resource_version) { "21943006" }
    let(:started_at) { "2020-07-22T18:47:08Z" }
    let(:pods) do
      metadata = double(:name => deployment_name, :labels => double(:name => pod_label))
      state = double(:running => double(:startedAt => started_at))
      last_state = double(:terminated => nil)
      status = double(:containerStatuses => [double(:state => state, :lastState => last_state, :restartCount => 0)])
      pods = [double(:metadata => metadata, :status => status)]
      allow(pods).to receive(:resourceVersion).and_return(resource_version)
      pods
    end

    before do
      allow(orchestrator).to receive(:get_pods).and_return(pods)
    end

    it "collects deployments optionally" do
      deploy = double
      deployments = [deploy]
      allow(deployments).to receive(:resourceVersion).and_return(resource_version)
      allow(orchestrator).to receive(:get_deployments).and_return(deployments)
      expect(server.worker_manager).to receive(:save_deployment).with(deploy)
      server.worker_manager.send(:collect_initial, :deployments)
    end

    it "calls save_pod for running pod" do
      server.worker_manager.send(:collect_initial)

      expect(server.worker_manager.current_pods[deployment_name][:label_name]).to eq(pod_label)
      expect(server.worker_manager.current_pods[deployment_name][:last_state_terminated]).to eq(false)
      expect(server.worker_manager.current_pods[deployment_name][:container_restarts]).to eq(0)
    end

    it "calls save_pod to update a known running pod" do
      pod_hash = Concurrent::Hash.new
      pod_hash[:label_name] = pod_label
      pod_hash[:last_state_terminated] = true

      server.worker_manager.current_pods[deployment_name] = pod_hash
      expect(server.worker_manager.current_pods[deployment_name][:last_state_terminated]).to eq(true)

      server.worker_manager.send(:collect_initial)
      expect(server.worker_manager.current_pods[deployment_name][:last_state_terminated]).to eq(false)
    end

    it "calls save_pod for terminated pod" do
      allow(pods.first.status.containerStatuses.first.lastState).to receive(:terminated).and_return(double(:exitCode => 1, :reason => "Error"))
      allow(pods.first.status.containerStatuses.first.state).to receive(:running).and_return(nil)
      allow(pods.first.status.containerStatuses.first).to receive(:restartCount).and_return(10)
      server.worker_manager.send(:collect_initial)

      expect(server.worker_manager.current_pods[deployment_name][:label_name]).to eq(pod_label)
      expect(server.worker_manager.current_pods[deployment_name][:last_state_terminated]).to eq(true)
      expect(server.worker_manager.current_pods[deployment_name][:container_restarts]).to eq(10)
    end

    it "returns resource_version" do
      expect(server.worker_manager.send(:collect_initial)).to eq(resource_version)
    end
  end

  context "#watch_for_events(private)" do
    let(:event_object) { double }

    let(:watch_event) do
      double(:object => event_object)
    end

    context "processes event" do
      before do
        allow(orchestrator).to receive(:watch_pods).and_return([watch_event])
      end

      it "ADDED calls save_pod with event object" do
        allow(watch_event).to receive(:type).and_return("ADDED")
        expect(server.worker_manager).to receive(:save_pod).with(event_object)
        server.worker_manager.send(:watch_for_events, :pods, nil)
      end

      it "MODIFIED calls save_pod with event object" do
        allow(watch_event).to receive(:type).and_return("MODIFIED")
        expect(server.worker_manager).to receive(:save_pod).with(event_object)
        server.worker_manager.send(:watch_for_events, :pods, nil)
      end

      it "DELETED calls delete_pod with event object" do
        allow(watch_event).to receive(:type).and_return("DELETED")
        expect(server.worker_manager).to receive(:delete_pod).with(event_object)
        server.worker_manager.send(:watch_for_events, :pods, nil)
      end

      it "UNKNOWN type isn't saved or deleted" do
        allow(watch_event).to receive(:type).and_return("UNKNOWN")
        expect(server.worker_manager).to receive(:save_pod).never
        expect(server.worker_manager).to receive(:delete_pod).never
        server.worker_manager.send(:watch_for_events, :pods, nil)
      end

      it "ERROR logs warning and breaks" do
        expected_code = 410
        expected_message = "too old resource version: 199900 (27177196)"
        expected_reason = "Gone"

        allow(watch_event).to receive(:type).and_return("ERROR")
        allow(event_object).to receive(:code).and_return(expected_code)
        allow(event_object).to receive(:message).and_return(expected_message)
        allow(event_object).to receive(:reason).and_return(expected_reason)

        allow(server.worker_manager).to receive(:log_pod_error_event) do |code, message, reason|
          expect(code).to eq(expected_code)
          expect(message).to eq(expected_message)
          expect(reason).to eq(expected_reason)
        end

        server.worker_manager.send(:watch_for_events, :pods, nil)
      end
    end
  end

  context "#sync_deployment_settings" do
    let(:worker1) { FactoryBot.create(:miq_generic_worker, :miq_server => server) }
    let(:worker2) { FactoryBot.create(:miq_generic_worker, :miq_server => server) }
    let(:worker3) { FactoryBot.create(:miq_priority_worker, :miq_server => server) }

    it "calls patch_deployment when changed" do
      allow(server.worker_manager).to receive(:miq_workers).and_return([worker1])
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker1).and_return(true)
      expect(worker1).to receive(:patch_deployment)
      server.worker_manager.sync_deployment_settings
    end

    it "doesn't call patch_deployment when unchanged" do
      allow(server.worker_manager).to receive(:miq_workers).and_return([worker1])
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker1).and_return(false)
      expect(worker1).to receive(:patch_deployment).never
      server.worker_manager.sync_deployment_settings
    end

    it "calls patch_deployment when changed once per worker class" do
      allow(server.worker_manager).to receive(:miq_workers).and_return([worker1, worker2, worker3])
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker1).and_return(true)
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker3).and_return(true)
      expect(worker1).to receive(:patch_deployment)
      expect(worker2).to receive(:patch_deployment).never
      expect(worker3).to receive(:patch_deployment)
      server.worker_manager.sync_deployment_settings
    end

    it "skips worker classes missing their deployment" do
      allow(server.worker_manager).to receive(:miq_workers).and_return([worker1, worker3])
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker1).and_return(true)
      allow(server.worker_manager).to receive(:deployment_resource_constraints_changed?).with(worker3).and_return(true)
      allow(worker1).to receive(:patch_deployment).and_raise(StandardError.new("AHHHHHH!"))
      expect(worker3).to receive(:patch_deployment)
      server.worker_manager.sync_deployment_settings
    end
  end

  context "deployment_resource_constraints_changed?" do
    let(:constraint_one) { {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}} }
    let(:deployment) do
      {
        :spec => {
          :template => {
            :spec => {
              :containers => [:resources => constraint_one]
            }
          }
        }
      }
    end
    let(:worker) { FactoryBot.create(:miq_generic_worker, :miq_server => server) }

    it "empty current_deployments" do
      stub_settings(:server => {:worker_monitor => {:enforce_resource_constraints => true}})
      server.worker_manager.current_deployments[worker.worker_deployment_name] = nil
      allow(worker).to receive(:resource_constraints).and_return(constraint_one)
      expect(server.worker_manager).to receive(:constraints_changed?).with({}, constraint_one)
      server.worker_manager.deployment_resource_constraints_changed?(worker)
    end

    it "normal" do
      stub_settings(:server => {:worker_monitor => {:enforce_resource_constraints => true}})
      server.worker_manager.current_deployments[worker.worker_deployment_name] = deployment
      allow(worker).to receive(:resource_constraints).and_return(constraint_one)
      expect(server.worker_manager).to receive(:constraints_changed?).with(constraint_one, constraint_one)
      server.worker_manager.deployment_resource_constraints_changed?(worker)
    end

    it "detects no changes if not enforced" do
      stub_settings(:server => {:worker_monitor => {:enforce_resource_constraints => false}})
      expect(server.worker_manager).to receive(:constraints_changed?).never
      expect(server.worker_manager.deployment_resource_constraints_changed?(worker)).to eq(false)
    end
  end

  context "constraints_changed?" do
    let(:empty) { {} }
    let(:constraint_one) { {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}} }
    let(:constraint_two) { {:limits => {:cpu => "888m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}} }

    it "No current, no desired constraints" do
      expect(server.worker_manager.constraints_changed?(empty, empty)).to eq(false)
    end

    it "No current, new desired constraints" do
      expect(server.worker_manager.constraints_changed?(empty, constraint_one)).to eq(true)
    end

    it "Current equals desired" do
      expect(server.worker_manager.constraints_changed?(constraint_one, constraint_one)).to eq(false)
    end

    it "Current does not equal desired" do
      expect(server.worker_manager.constraints_changed?(constraint_one, constraint_two)).to eq(true)
    end

    it "Detects 1024Mi memory == 1Gi" do
      new_value = {:limits => {:memory => "1024Mi"}}
      expect(server.worker_manager.constraints_changed?(constraint_one, constraint_one.deep_merge(new_value))).to eq(false)
    end

    it "Detects 0.15 == 150m" do
      # From: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits
      # A request with a decimal point, like 0.1, is converted to 100m by the API, and precision finer than 1m is not allowed. For this reason, the form 100m might be preferred.
      new_value = {:requests => {:cpu => "0.15"}}
      expect(server.worker_manager.constraints_changed?(constraint_one, constraint_one.deep_merge(new_value))).to eq(false)
    end

    it "Current missing cpu limit" do
      current = {:limits => {:memory => "1Gi"},                 :requests => {:cpu => "150m", :memory => "500Mi"}}
      desired = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}}
      expect(server.worker_manager.constraints_changed?(current, desired)).to eq(true)
    end

    it "Desired missing cpu limit" do
      current = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}}
      desired = {:limits => {:memory => "1Gi"},                 :requests => {:cpu => "150m", :memory => "500Mi"}}
      expect(server.worker_manager.constraints_changed?(current, desired)).to eq(true)
    end

    it "Current missing memory request" do
      current = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m"}}
      desired = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}}
      expect(server.worker_manager.constraints_changed?(current, desired)).to eq(true)
    end

    it "Desired missing memory request" do
      current = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m", :memory => "500Mi"}}
      desired = {:limits => {:cpu => "999m", :memory => "1Gi"}, :requests => {:cpu => "150m"}}
      expect(server.worker_manager.constraints_changed?(current, desired)).to eq(true)
    end

    it "checks millicores" do
      current = constraint_one.deep_merge(:limits => {:cpu => "1"})
      desired = constraint_one.deep_merge(:limits => {:cpu => "1000m"})
      expect(server.worker_manager.constraints_changed?(current, desired)).to eq(false)
    end
  end
end
