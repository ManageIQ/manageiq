RSpec.describe MiqWorker::SystemdCommon do
  describe ".service_base_name" do
    before { MiqWorkerType.seed }

    it "every worker has a matching systemd target and service file", :providers_common => true do
      expected_units = (Vmdb::Plugins.systemd_units + Rails.root.join("systemd").glob("*.*")).map(&:basename).map(&:to_s)

      expected_units.delete("manageiq.target")

      found_units = MiqWorkerType.worker_class_names.flat_map do |klass_name|
        klass = klass_name.constantize
        service_base_name = klass.service_base_name

        service_file = "#{service_base_name}@.service"
        target_file  = "#{service_base_name}.target"

        [service_file, target_file]
      end

      expect(expected_units).to match_array(found_units)
    end
  end
end
