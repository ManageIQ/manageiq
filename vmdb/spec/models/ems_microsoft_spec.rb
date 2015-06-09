require "spec_helper"

describe EmsMicrosoft do
  it ".ems_type" do
    described_class.ems_type.should == 'scvmm'
  end

  it ".description" do
    described_class.description.should == 'Microsoft System Center VMM'
  end

  it ".auth_url handles ipv6" do
    described_class.auth_url("::1").should == "http://[::1]:5985/wsman"
  end

  context "#connect with ssl" do
    before do
      @e = FactoryGirl.create(:ems_microsoft, :hostname => "host", :security_protocol => "ssl", :ipaddress => "127.0.0.1")
      @e.authentications << FactoryGirl.create(:authentication, :userid => "user", :password => "pass")
    end

    it "defaults" do
      described_class.should_receive(:raw_connect).with do |url, protocol, creds|
        url.should match(/host/)
        protocol.should be == "ssl"
        creds[:user].should be == "user"
        creds[:pass].should be == "pass"
      end

      @e.connect
    end

    it "accepts overrides" do
      described_class.should_receive(:raw_connect).with do |url, protocol, creds|
        url.should match(/host2/)
        protocol.should be == "ssl"
        creds[:user].should be == "user2"
        creds[:pass].should be == "pass2"
      end

      @e.connect(:user => "user2", :pass => "pass2", :hostname => "host2")
    end
  end

  context "#connect with kerberos" do
    before do
      @e = FactoryGirl.create(:ems_microsoft, :hostname => "host", :security_protocol => "kerberos", :realm => "pretendrealm", :ipaddress => "127.0.0.1")
      @e.authentications << FactoryGirl.create(:authentication, :userid => "user", :password => "pass")
    end

    it "defaults" do
      described_class.should_receive(:raw_connect).with do |url, protocol, creds|
        url.should match(/host/)
        protocol.should be == "kerberos"
        creds[:user].should be == "user"
        creds[:pass].should be == "pass"
        creds[:realm].should be == "pretendrealm"
      end

      @e.connect
    end

    it "accepts overrides" do
      described_class.should_receive(:raw_connect).with do |url, protocol, creds|
        url.should match(/host2/)
        protocol.should be == "kerberos"
        creds[:user].should be == "user2"
        creds[:pass].should be == "pass2"
        creds[:realm].should be == "pretendrealm"
      end

      @e.connect(:user => "user2", :pass => "pass2", :hostname => "host2")
    end
  end
end
