module MiqAeServiceContainerBuildSpec
  describe MiqAeMethodService::MiqAeServiceContainerBuild do
    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#container_project" do
      expect(described_class.instance_methods).to include(:container_project)
    end

    it "#container_build_pods" do
      expect(described_class.instance_methods).to include(:container_build_pods)
    end
  end
end
