RSpec.describe ContainerImage do
  subject { FactoryBot.create(:container_image) }

  include_examples "MiqPolicyMixin"

  it "#full_name" do
    image = ContainerImage.new(:name => "fedora")
    expect(image.full_name).to eq("fedora")

    image.tag = "v1"
    expect(image.full_name).to eq("fedora:v1")

    reg = ContainerImageRegistry.new(:name => "docker.io", :host => "docker.io", :port => "1234")
    image.container_image_registry = reg
    expect(image.full_name).to eq("docker.io:1234/fedora:v1")

    image.image_ref = "docker-pullable://registry/repo/name@id"
    expect(image.full_name).to eq("registry/repo/name@id")
  end

  context "#display_registry" do
    it "finds unknown with unknown name" do
      image = ContainerImage.new(:name => "fedora")
      expect(image.display_registry).to eq("Unknown image source")
    end

    it "localizes for unknown" do
      I18n.with_locale(:es) do
        image = ContainerImage.new(:name => "fedora")
        reg = image.display_registry
        expect(reg).to eq("Fuente de imagen desconocida")
      end
    end

    it "finds name with valid name" do
      image = ContainerImage.new(:name => "fedora")
      reg = ContainerImageRegistry.new(:name => "docker.io", :host => "docker.io", :port => "1234")
      image.container_image_registry = reg
      expect(image.display_registry).to eq("docker.io:1234")
    end
  end

  it "#docker_id" do
    image = FactoryBot.create(:container_image, :image_ref => "docker://id")
    expect(image.docker_id).to eq("id")

    image = FactoryBot.create(:container_image, :image_ref => "docker-pullable://repo/name@id")
    expect(image.docker_id).to eq("repo/name@id")

    image = FactoryBot.create(:container_image, :image_ref => "rocket://id")
    expect(image.docker_id).to eq(nil)
  end

  it "#operating_system=" do
    image = FactoryBot.create(:container_image)
    expect(image.computer_system).to be_nil

    image.operating_system = FactoryBot.create(:operating_system)
    expect(image.computer_system).not_to be_nil
    expect(image.operating_system).to eq(image.computer_system.operating_system)
  end
end
