describe ManageIQ::Providers::Microsoft::InfraManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('scvmm')
  end

  it ".description" do
    expect(described_class.description).to eq('Microsoft System Center VMM')
  end

  it ".auth_url handles ipv6" do
    expect(described_class.auth_url("::1")).to eq("http://[::1]:5985/wsman")
  end

  context "#connect with ssl" do
    before do
      @e = FactoryGirl.create(:ems_microsoft, :hostname => "host", :security_protocol => "ssl", :ipaddress => "127.0.0.1")
      @e.authentications << FactoryGirl.create(:authentication, :userid => "user", :password => "pass")
    end

    it "defaults" do
      expect(described_class).to receive(:raw_connect) do |url, protocol, creds|
        expect(url).to match(/host/)
        expect(protocol).to eq("ssl")
        expect(creds[:user]).to eq("user")
        expect(creds[:pass]).to eq("pass")
      end

      @e.connect
    end

    it "accepts overrides" do
      expect(described_class).to receive(:raw_connect) do |url, protocol, creds|
        expect(url).to match(/host2/)
        expect(protocol).to eq("ssl")
        expect(creds[:user]).to eq("user2")
        expect(creds[:pass]).to eq("pass2")
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
      expect(described_class).to receive(:raw_connect) do |url, protocol, creds|
        expect(url).to match(/host/)
        expect(protocol).to eq("kerberos")
        expect(creds[:user]).to eq("user")
        expect(creds[:pass]).to eq("pass")
        expect(creds[:realm]).to eq("pretendrealm")
      end

      @e.connect
    end

    it "accepts overrides" do
      expect(described_class).to receive(:raw_connect) do |url, protocol, creds|
        expect(url).to match(/host2/)
        expect(protocol).to eq("kerberos")
        expect(creds[:user]).to eq("user2")
        expect(creds[:pass]).to eq("pass2")
        expect(creds[:realm]).to eq("pretendrealm")
      end

      @e.connect(:user => "user2", :pass => "pass2", :hostname => "host2")
    end
  end
end
