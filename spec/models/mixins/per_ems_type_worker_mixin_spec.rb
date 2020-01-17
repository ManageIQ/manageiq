RSpec.describe PerEmsTypeWorkerMixin do
  let(:worker)       { FactoryBot.create(:miq_ems_metrics_collector_worker) }
  let(:worker_class) { worker.class }

  before do
    _guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  describe ".workers" do
    it "is 0 with no providers" do
      expect(worker_class.workers).to eq(0)
    end

    context "with a provider" do
      let!(:provider) { FactoryBot.create(:ems_vmware, :with_authentication, :zone => @zone) }

      it "is 0 without the role active" do
        expect(worker_class.workers).to eq(0)
      end

      context "with the role active" do
        before do
          ServerRole.seed
          @server.role = "ems_metrics_collector"
          @server.assigned_server_roles.update(:active => true)
        end

        it "is the number configured" do
          configured = worker_class.workers_configured_count
          expect(worker_class.workers).to eq(configured)

          stub_settings(:workers => {:worker_base => {:queue_worker_base => {:ems_metrics_collector_worker => {:count => configured + 1}}}})
          expect(worker_class.workers).to eq(configured + 1)
        end

        it "is 0 with the provider in the wrong zone" do
          other_zone = FactoryBot.create(:zone)
          provider.update(:zone => other_zone)
          stub_settings(:workers => {:worker_base => {:queue_worker_base => {:ems_metrics_collector_worker => {:count => 5}}}})

          expect(worker_class.workers).to eq(0)
        end
      end
    end
  end
end
