RSpec.describe MiqWorker::SystemdCommon do
  describe ".service_base_name" do
    before { MiqWorkerType.seed }

    it "every worker has a matching systemd target and service file", :providers_common => true do
      expected_units = (Vmdb::Plugins.systemd_units + Rails.root.join("systemd").glob("*.*")).map(&:basename).map(&:to_s)

      expected_units -= %w[manageiq-db-ready.service manageiq-messaging-ready.service evmserverd.service manageiq.target]

      found_units = MiqWorkerType.worker_classes.flat_map do |worker_class|
        service_base_name = worker_class.service_base_name

        service_file = "#{service_base_name}@.service"
        target_file  = "#{service_base_name}.target"

        [service_file, target_file]
      end

      expect(found_units).to match_array(expected_units)
    end
  end
end
