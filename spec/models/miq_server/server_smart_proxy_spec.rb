RSpec.describe "MiqServer::ServerSmartProxy" do
  let(:server) { EvmSpecHelper.local_miq_server }
  before { ServerRole.seed }

  describe "#is_vix_disk?" do
    it "is false without the smartproxy role" do
      server.update(:has_vix_disk_lib => true)
      expect(server.is_vix_disk?).to be_falsey
    end

    it "is true with smartproxy and vix disk lib" do
      server.update(:has_vix_disk_lib => true)
      server.role = "smartproxy"
      server.assigned_server_roles.update(:active => true)

      expect(server.is_vix_disk?).to be_truthy
    end
  end

  describe "#concurrent_job_max" do
    it "is 0 without the smartproxy role" do
      expect(server.concurrent_job_max).to eq(0)
    end

    it "is the number of smart proxy workers when the role is active" do
      server.role = "smartproxy"
      server.assigned_server_roles.update(:active => true)
      stub_settings(:workers => {:worker_base => {:queue_worker_base => {:smart_proxy_worker => {:count => 5}}}})

      expect(server.concurrent_job_max).to eq(5)
    end
  end
end
