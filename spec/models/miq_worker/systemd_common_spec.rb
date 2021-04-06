RSpec.describe MiqWorker::SystemdCommon do
  describe ".service_base_name" do
    before { MiqWorkerType.seed }

    it "every worker has a matching systemd target and service file" do
      all_systemd_units = (Vmdb::Plugins.systemd_units + Rails.root.join("systemd").glob("*.*")).map(&:basename).map(&:to_s)

      all_systemd_units.delete("manageiq.target")

      MiqWorkerType.worker_class_names.each do |klass_name|
        klass = klass_name.constantize
        service_base_name = klass.service_base_name

        service_file = "#{service_base_name}@.service"
        target_file  = "#{service_base_name}.target"

        expect(all_systemd_units).to include(service_file)
        expect(all_systemd_units).to include(target_file)

        all_systemd_units -= [service_file, target_file]
      end

      expect(all_systemd_units).to be_empty
    end
  end
end
