describe ContainerImage do
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

  it "#display_registry" do
    image = ContainerImage.new(:name => "fedora")
    expect(image.display_registry).to eq("Unknown image source")

    reg = ContainerImageRegistry.new(:name => "docker.io", :host => "docker.io", :port => "1234")
    image.container_image_registry = reg
    expect(image.display_registry).to eq("docker.io:1234")
  end

  it "#docker_id" do
    image = FactoryGirl.create(:container_image, :image_ref => "docker://id")
    expect(image.docker_id).to eq("id")

    image = FactoryGirl.create(:container_image, :image_ref => "docker-pullable://repo/name@id")
    expect(image.docker_id).to eq("repo/name@id")

    image = FactoryGirl.create(:container_image, :image_ref => "rocket://id")
    expect(image.docker_id).to eq(nil)
  end

  it "#operating_system=" do
    image = FactoryGirl.create(:container_image)
    expect(image.computer_system).to be_nil

    image.operating_system = FactoryGirl.create(:operating_system)
    expect(image.computer_system).not_to be_nil
    expect(image.operating_system).to eq(image.computer_system.operating_system)
  end

  context "#annotate_deny_execution" do
    it "does not crush if annotating non existent image" do
      osp = FactoryGirl.create(:ems_openshift, :hostname => "test.com")
      allow(osp).to receive(:annotate) { raise KubeException.new(404, "Can't find image!", nil) }
      image = FactoryGirl.create(:container_image, :ext_management_system => osp)
      expect(osp).to receive(:annotate)
      image.annotate_deny_execution("test policy")
    end

    it "crushes when annotating crushes for un expected error" do
      excp = KubeException.new(500, "Something Awful happend!", nil)
      osp = FactoryGirl.create(:ems_openshift, :hostname => "test.com")
      allow(osp).to receive(:annotate) { raise excp }
      image = FactoryGirl.create(:container_image, :ext_management_system => osp)
      expect(osp).to receive(:annotate)
      expect { image.annotate_deny_execution("test policy") }.to raise_error { excp }
    end
  end
end
