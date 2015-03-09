require "spec_helper"

describe EmsMicrosoft do
  it ".ems_type" do
    described_class.ems_type.should == 'scvmm'
  end

  it ".description" do
    described_class.description.should == 'Microsoft System Center VMM'
  end

  context "#connect" do
    before do
      @e = FactoryGirl.create(:ems_microsoft, :hostname => "host", :ipaddress => "127.0.0.1")
      @e.authentications << FactoryGirl.create(:authentication, :userid => "user", :password => "pass")
    end

    it "defaults" do
      described_class.should_receive(:raw_connect).with do |u, p, url|
        u.should == "user"
        p.should == "pass"
        url.should match(/host/)
      end

      @e.connect
    end

    it "accepts overrides" do
      described_class.should_receive(:raw_connect).with do |u, p, url|
        u.should == "user2"
        p.should == "pass2"
        url.should match(/host2/)
      end

      @e.connect(:user => "user2", :pass => "pass2", :hostname => "host2")
    end
  end
end
