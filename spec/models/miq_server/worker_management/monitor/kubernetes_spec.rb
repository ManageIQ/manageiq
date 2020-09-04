RSpec.describe MiqServer::WorkerManagement::Monitor::Kubernetes do
  let(:server)          { EvmSpecHelper.create_guid_miq_server_zone.second }
  let(:orchestrator)    { double("ContainerOrchestrator") }
  let(:deployment_name) { '1-generic-79bb8b8bb5-8ggbg' }
  let(:pod_label)       { '1-generic' }

  before do
    # MiqWorkerType.seed
    allow(server).to receive(:orchestrator).and_return(orchestrator)
  end

  after do
    server.reset_current_pods
  end

  context "#cleanup_failed_deployments" do
    context "#ensure_pod_monitor_started" do
      before do
        allow(server).to receive(:delete_failed_deployments)
      end

      it "calls start_pod_monitor if nil monitor thread" do
        expect(server).to receive(:start_pod_monitor)
        server.instance_variable_set(:@monitor_thread, nil)
        server.cleanup_failed_deployments
      end

      it "calls start_pod_monitor if monitor thread terminated normally" do
        expect(server).to receive(:start_pod_monitor)
        thread = double(:alive? => false, :status => false)
        expect(thread).to receive(:join).never

        server.instance_variable_set(:@monitor_thread, thread)
        server.cleanup_failed_deployments
      end

      it "joins a dead thread with an exception before calling start_pod_monitor" do
        expect(server).to receive(:start_pod_monitor)
        thread = double(:alive? => false, :status => nil)
        expect(thread).to receive(:join).once

        server.instance_variable_set(:@monitor_thread, thread)
        server.cleanup_failed_deployments
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
        allow(server).to receive(:ensure_pod_monitor_started)
      end

      context "with no deployments" do
        it "doesn't call delete_deployment" do
          allow(server).to receive(:current_pods).and_return(Concurrent::Hash.new)
          expect(orchestrator).to receive(:delete_deployment).never
          server.cleanup_failed_deployments
        end
      end

      context "with 1 running deployment" do
        it "doesn't call delete_deployment" do
          allow(server).to receive(:current_pods).and_return(current_pods)
          expect(orchestrator).to receive(:delete_deployment).never
          server.cleanup_failed_deployments
        end
      end

      context "with a failed deployment" do
        it "calls delete_deployment with pod name" do
          current_pods[deployment_name][:last_state_terminated] = true
          current_pods[deployment_name][:container_restarts] = 100

          allow(server).to receive(:current_pods).and_return(current_pods)
          expect(orchestrator).to receive(:delete_deployment).with(pod_label)
          server.cleanup_failed_deployments
        end
      end
    end
  end

  context "#collect_initial_pods(private)" do
    let(:resource_version) { "21943006" }
    let(:started_at) { "2020-07-22T18:47:08Z" }
    let(:pods) do
      metadata = double(:name => deployment_name, :labels => double(:name => pod_label))
      state = double(:running => double(:startedAt => started_at))
      lastState = double(:terminated => nil)
      status = double(:containerStatuses => [double(:state => state, :lastState => lastState, :restartCount => 0)])
      pods = [double(:metadata => metadata, :status => status)]
      allow(pods).to receive(:resourceVersion).and_return(resource_version)
      pods
    end

    before do
      allow(orchestrator).to receive(:get_pods).and_return(pods)
    end

    it "calls save_pod for running pod" do
      server.send(:collect_initial_pods)

      expect(server.current_pods[deployment_name][:label_name]).to eql(pod_label)
      expect(server.pod_resource_version).to eql(resource_version)
      expect(server.current_pods[deployment_name][:last_state_terminated]).to eql(false)
      expect(server.current_pods[deployment_name][:container_restarts]).to eql(0)
    end

    it "calls save_pod to update a known running pod" do
      pod_hash = Concurrent::Hash.new
      pod_hash[:label_name] = pod_label
      pod_hash[:last_state_terminated] = true

      server.current_pods[deployment_name] = pod_hash
      expect(server.current_pods[deployment_name][:last_state_terminated]).to eql(true)

      server.send(:collect_initial_pods)
      expect(server.current_pods[deployment_name][:last_state_terminated]).to eql(false)
    end

    it "calls save_pod for terminated pod" do
      allow(pods.first.status.containerStatuses.first.lastState).to receive(:terminated).and_return(double(:exitCode => 1, :reason => "Error"))
      allow(pods.first.status.containerStatuses.first.state).to receive(:running).and_return(nil)
      allow(pods.first.status.containerStatuses.first).to receive(:restartCount).and_return(10)
      server.send(:collect_initial_pods)

      expect(server.current_pods[deployment_name][:label_name]).to eql(pod_label)
      expect(server.current_pods[deployment_name][:last_state_terminated]).to eql(true)
      expect(server.current_pods[deployment_name][:container_restarts]).to eql(10)
    end

    it "sets get_pods resource_version" do
      server.send(:collect_initial_pods)
      expect(server.pod_resource_version).to eql(resource_version)
    end
  end

  context "#watch_for_pod_events(private)" do
    let(:event_object) { double }

    let(:watch_event) do
      double(:object => event_object)
    end

    it "ensures watcher.finish" do
      watcher = double
      allow(orchestrator).to receive(:watch_pods).and_return(watcher)
      expect(watcher).to receive(:finish)
      server.send(:watch_for_pod_events)
    end

    context "processes event" do
      before do
        allow(orchestrator).to receive(:watch_pods).and_yield(watch_event)
      end

      it "ADDED calls save_pod with event object" do
        allow(watch_event).to receive(:type).and_return("ADDED")
        expect(server).to receive(:save_pod).with(event_object)
        server.send(:watch_for_pod_events)
      end

      it "MODIFIED calls save_pod with event object" do
        allow(watch_event).to receive(:type).and_return("MODIFIED")
        expect(server).to receive(:save_pod).with(event_object)
        server.send(:watch_for_pod_events)
      end

      it "DELETED calls delete_pod with event object" do
        allow(watch_event).to receive(:type).and_return("DELETED")
        expect(server).to receive(:delete_pod).with(event_object)
        server.send(:watch_for_pod_events)
      end

      it "UNKNOWN type isn't saved or deleted" do
        allow(watch_event).to receive(:type).and_return("UNKNOWN")
        expect(server).to receive(:save_pod).never
        expect(server).to receive(:delete_pod).never
        server.send(:watch_for_pod_events)
      end

      it "ERROR logs warning, resets pod_resource_version and breaks" do
        server.pod_resource_version = 1000
        expected_code = 410
        expected_message = "too old resource version: 199900 (27177196)"
        expected_reason = "Gone"

        allow(watch_event).to receive(:type).and_return("ERROR")
        allow(event_object).to receive(:code).and_return(expected_code)
        allow(event_object).to receive(:message).and_return(expected_message)
        allow(event_object).to receive(:reason).and_return(expected_reason)

        allow(server).to receive(:log_pod_error_event) do |code, message, reason|
          expect(code).to eql(expected_code)
          expect(message).to eql(expected_message)
          expect(reason).to eql(expected_reason)
        end

        server.send(:watch_for_pod_events)
        expect(server.pod_resource_version).to eql(nil)
      end
    end
  end
end
