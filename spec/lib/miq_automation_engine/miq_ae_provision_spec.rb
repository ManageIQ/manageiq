describe "MiqAeProvision" do
  let(:expected_customization) do
  {
    :password             => {
      :plaintext => "true"
    },
    :guiUnattended        => {
      :autoLogon      => 0,
      :autoLogonCount => 1,
      :timeZone       => 105
    },
    :identification       => {
      :joinWorkgroup => 'WORKGROUP'
    },
    :licenseFilePrintData => {
      :autoMode => 'perSeat'
    },
    :userData             => {
      :fullName  => 'MyCompany',
      :orgName   => 'MyCompany',
      :productId => 'VRXXR-VJC3H-YVWYT-HCPDD-HFMQ3'
    },
    :globalIPSettings     => {
      :dnsServerList => ["192.168.254.16", "192.168.254.17"],
      :dnsSuffixList => ["galaxy.local"]
    },
    :fixedIp              => {
      :ipAddress => "192.168.254.125"
    },
    :ipSettings           => {
      :subnetMask    => "255.255.255.0",
      :gateway       => [""],
      :dnsDomain     => "galaxy.local",
      :dnsServerList => ["192.168.254.16", "192.168.254.17"],
    },
    :winOptions           => {
      :changeSID      => 1,
      :deleteAccounts => 0
    }
  }
  end

  context "Using provision yaml model" do
    before(:each) do
      @domain = 'SPEC_DOMAIN'
      @user = FactoryGirl.create(:user_with_group)
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      MiqAeDatastore.reset
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "provision"), @domain)
    end

    it "should instantiate lease_times" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_lease_times", @user)
      expect(ws).not_to be_nil
      ttls  = ws.root("ttls")
      expect(ttls.class.name).to eq("Hash")
      expect(ttls.length).to eq(5)
    end

    it "should properly instantiate /EVMApplications/Provisioning/Information/Default#debug" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#debug", @user)
      expect(ws).not_to be_nil
      roots = ws.roots
      expect(roots).not_to be_nil
      expect(roots).to be_a_kind_of(Array)
      expect(roots.length).to eq(1)
    end

    it "should instantiate ttl_warnings" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_ttl_warnings", @user)
      expect(ws).not_to be_nil
      warnings = ws.root("warnings")
      expect(warnings.class.name).to eq("Hash")
      expect(warnings.length).to eq(3)
    end

    it "should instantiate allowed_num_vms" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=dev#get_allowed_num_vms", @user)
      expect(ws).not_to be_nil
      expect(ws.root("allowed")).to eq(3)

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=test#get_allowed_num_vms", @user)
      expect(ws).not_to be_nil
      expect(ws.root("allowed")).to eq(5)

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=foo#get_allowed_num_vms", @user)
      expect(ws).not_to be_nil
      expect(ws.root("allowed")).to eq(1)

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=#get_allowed_num_vms", @user)
      expect(ws).not_to be_nil
      expect(ws.root("allowed")).to eq(0)

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_allowed_num_vms", @user)
      expect(ws).not_to be_nil
      expect(ws.root("allowed")).to eq(0)
    end

    it "should instantiate container_info" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=dev#get_container_info", @user)
      expect(ws).not_to be_nil
      expect(ws.root("ncpus")).to eq(1)
      expect(ws.root("memory")).to eq(1)
      expect(ws.root("vlan")).to eq("dev")

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=test#get_container_info", @user)
      expect(ws).not_to be_nil
      expect(ws.root("ncpus")).to eq(2)
      expect(ws.root("memory")).to be_nil
      expect(ws.root("vlan")).to be_nil

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=prod#get_container_info", @user)
      expect(ws).not_to be_nil
      expect(ws.root("ncpus")).to be_nil
      expect(ws.root("memory")).to eq(4)
      expect(ws.root("vlan")).to eq("production")

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=foo#get_container_info", @user)
      expect(ws).not_to be_nil
      expect(ws.root("ncpus")).to be_nil
      expect(ws.root("memory")).to be_nil
      expect(ws.root("vlan")).to be_nil
    end

    it "should instantiate customization" do
      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_customization", @user)
      expect(ws).not_to be_nil
      expect(ws.root("customization")).to eq(expected_customization)
    end

    it "should have Network class" do
      fqname = "#{@domain}/EVMApplications/Provisioning/Network"
      klass = MiqAeClass.find_by_fqname(fqname)
      expect(klass).not_to be_nil
      expect(klass.ae_instances.length).not_to eq(0)

      ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_networks", @user)
      expect(ws).not_to be_nil

      networks = ws.root['networks']
      expect(networks).not_to be_nil
      expect(networks).to be_a_kind_of(Array)
      networks.each { |network|
        expect(network).to be_a_kind_of(Hash)
        [:scope, :vlan, :vc_id, :dhcp_servers].each { |key| expect(network).to have_key(key) }
        expect(network[:dhcp_servers]).to be_a_kind_of(Array)
        network[:dhcp_servers].each { |dhcp|
          expect(dhcp).to be_a_kind_of(Hash)
          [:domain, :ip, :name].each { |key| expect(dhcp).to have_key(key) }
          expect(dhcp[:domain]).to be_a_kind_of(Hash)
          [:base_dn, :bind_dn, :bind_password, :ldap_host, :ldap_port, :user_type, :name].each { |key| expect(dhcp[:domain]).to have_key(key) }
        }
      }
    end
  end
end
