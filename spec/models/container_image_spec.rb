require "spec_helper"

describe ContainerImage do
  it "#full_name" do
    image = ContainerImage.new(:name => "fedora")
    expect(image.full_name).to eq("fedora")

    image.tag = "v1"
    expect(image.full_name).to eq("fedora:v1")

    reg = ContainerImageRegistry.new(:name => "docker.io", :host => "docker.io", :port => "1234")
    image.container_image_registry = reg
    expect(image.full_name).to eq("docker.io:1234/fedora:v1")
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
end
