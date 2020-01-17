RSpec.describe ContainerImageRegistry do
  it "#full_name" do
    reg = ContainerImageRegistry.new(:name => "docker.io", :host => "docker.io")
    expect(reg.full_name).to eq("docker.io")

    reg.port = "1234"
    expect(reg.full_name).to eq("docker.io:1234")
  end
end
