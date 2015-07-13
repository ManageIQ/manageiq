require "spec_helper"

describe ServiceResource do
  it "default values" do
    subject.group_idx.should       ==  0
    subject.scaling_min.should     ==  1
    subject.scaling_max.should     == -1
    subject.provision_index.should ==  0
  end

  context "with a nil resource" do
    it "#resource_name" do
      subject.resource_name.should == ""
    end

    it "#resource_description" do
      subject.resource_description.should == ""
    end
  end

  context "with a service as a resource" do
    before do
      @service = FactoryGirl.create(:service, :name => "Svc_A", :description => "Test Service")
      subject.resource = @service
    end

    it "#resource_name" do
      subject.resource_name.should == @service.name
    end

    it "#resource_description" do
      subject.resource_description.should == @service.description
    end
  end
end
