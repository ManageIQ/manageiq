RSpec.describe ContainerImageRegistry do
  describe "#full_name" do
    it "works with no port" do
      reg = FactoryBot.create(:container_image_registry, :name => "docker.io", :host => "docker.io")
      expect(reg.full_name).to eq("docker.io")

      reg = ContainerImageRegistry.where(:id => reg.id).select(:full_name).first
      expect(reg.full_name).to eq("docker.io")
    end

    it "works with port" do
      reg = FactoryBot.create(:container_image_registry, :name => "docker.io", :host => "docker.io", :port => "1234")
      expect(reg.full_name).to eq("docker.io:1234")

      reg = ContainerImageRegistry.where(:id => reg.id).select(:full_name).first
      expect(reg.full_name).to eq("docker.io:1234")
    end
  end
end
