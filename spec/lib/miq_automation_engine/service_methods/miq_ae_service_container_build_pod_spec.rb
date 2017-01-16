module MiqAeServiceContainerBuildPodSpec
  describe MiqAeMethodService::MiqAeServiceContainerBuildPod do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_build" do
      expect(described_class.instance_methods).to include(:container_build)
    end
  end
end
