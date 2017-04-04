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

  context "#refresh_openshift_information" do
    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
      hostname = 'host.example.com'
      token = 'theToken'

      @ems = FactoryGirl.create(
        :ems_openshift,
        :name                      => 'OpenShiftProvider',
        :connection_configurations => [{:endpoint       => {:role              => :default,
                                                            :hostname          => hostname,
                                                            :port              => "8443",
                                                            :security_protocol => nil,
                                                            :verify_ssl        => 0},
                                        :authentication => {:role     => :bearer,
                                                            :auth_key => token,
                                                            :userid   => "_"}}]
      )
    end

    it "fails gracefully when image doens't exist in Openshift" do
      image = FactoryGirl.create(:container_image,
                                 :ems_id => @ems.id,
                                 :digest => "sha256:not_a_real_digest")
      @ems.container_images << image

      VCR.use_cassette("#{described_class.name.underscore}_image_not_found",
                       :match_requests_on => [:path,]) do # , :record => :new_episodes) do
        image.refresh_openshift_information
        expect(image.architecture).to be(nil)
      end
    end

    it "updates correctly from Openshift" do
      digest = "sha256:15048638d6a0dfc1838b69305c0c15d823a13dc55b9f532771bbbe041b064c4a"
      image = FactoryGirl.create(:container_image,
                                 :ems_id => @ems.id,
                                 :digest => digest)
      @ems.container_images << image

      VCR.use_cassette("#{described_class.name.underscore}_happy_flow",
                       :match_requests_on => [:path,]) do # , :record => :new_episodes) do
        image.refresh_openshift_information
        expect(image.architecture).to eq("amd64")
      end
    end
  end
end
