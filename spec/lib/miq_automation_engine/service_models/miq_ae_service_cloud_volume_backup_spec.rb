module MiqAeServiceCloudVolumeBackupSpec
  describe MiqAeMethodService::MiqAeServiceCloudVolumeBackup do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#availability_zone" do
      expect(described_class.instance_methods).to include(:availability_zone)
    end

    it "#cloud_volume" do
      expect(described_class.instance_methods).to include(:cloud_volume)
    end
  end
end
