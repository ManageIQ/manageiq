require "spec_helper"

describe ContainerImageRegistry do
  it "tests full_name" do
    reg = ContainerImageRegistry.new(:name => "docker.io", :host =>"docker.io")
    reg.full_name.should == "docker.io"

    reg.port = "1234"
    reg.full_name.should == "docker.io:1234"
  end
end