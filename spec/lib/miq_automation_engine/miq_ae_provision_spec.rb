require "spec_helper"

module MiqAeProvisionSpec
  include MiqAeEngine
  describe "MiqAeProvision" do
    EXPECTED_CUSTOMIZATION = {
      :password => {
        :plaintext => "true"
      },
      :guiUnattended => {
        :autoLogon => 0,
        :autoLogonCount => 1,
        :timeZone => 105
      },
      :identification => {
        :joinWorkgroup => 'WORKGROUP'
      },
      :licenseFilePrintData => {
        :autoMode => 'perSeat'
      },
      :userData => {
        :fullName  => 'MyCompany',
        :orgName   => 'MyCompany',
        :productId => 'VRXXR-VJC3H-YVWYT-HCPDD-HFMQ3'
      },
      :globalIPSettings => {
        :dnsServerList => ["192.168.254.16", "192.168.254.17"],
        :dnsSuffixList => ["galaxy.local"]
      },
      :fixedIp => {
        :ipAddress => "192.168.254.125"
      },
      :ipSettings => {
        :subnetMask    => "255.255.255.0",
        :gateway       => [""],
        :dnsDomain     => "galaxy.local",
        :dnsServerList => ["192.168.254.16", "192.168.254.17"],
      },
      :winOptions => {
        :changeSID =>1,
        :deleteAccounts => 0
      }
    }

    context "Using provision yaml model" do
      before(:each) do
        @domain = 'SPEC_DOMAIN'
        @model_data_dir = File.join(File.dirname(__FILE__), "data")
        MiqAeDatastore.reset
        EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "provision"), @domain)
      end

      it "should instantiate lease_times" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_lease_times")
        ws.should_not be_nil
        ttls  = ws.root("ttls")
        ttls.class.name.should == "Hash"
        ttls.length.should == 5
      end

      it "should properly instantiate /EVMApplications/Provisioning/Information/Default#debug" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#debug")
        ws.should_not be_nil
        roots = ws.roots
        roots.should_not be_nil
        roots.should be_a_kind_of(Array)
        roots.length.should == 1
        roots.first.attributes.length.should == 0
      end

      it "should instantiate ttl_warnings" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_ttl_warnings")
        ws.should_not be_nil
        warnings = ws.root("warnings")
        warnings.class.name.should == "Hash"
        warnings.length.should == 3
      end

      it "should instantiate allowed_num_vms" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=dev#get_allowed_num_vms")
        ws.should_not be_nil
        ws.root("allowed").should == 3

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=test#get_allowed_num_vms")
        ws.should_not be_nil
        ws.root("allowed").should == 5

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=foo#get_allowed_num_vms")
        ws.should_not be_nil
        ws.root("allowed").should == 1

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=#get_allowed_num_vms")
        ws.should_not be_nil
        ws.root("allowed").should == 0

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_allowed_num_vms")
        ws.should_not be_nil
        ws.root("allowed").should == 0
      end

      it "should instantiate container_info" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=dev#get_container_info")
        ws.should_not be_nil
        ws.root("ncpus").should  == 1
        ws.root("memory").should == 1
        ws.root("vlan").should   == "dev"

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=test#get_container_info")
        ws.should_not be_nil
        ws.root("ncpus").should  == 2
        ws.root("memory").should be_nil
        ws.root("vlan").should be_nil

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=prod#get_container_info")
        ws.should_not be_nil
        ws.root("ncpus").should be_nil
        ws.root("memory").should  == 4
        ws.root("vlan").should =="production"

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default?environment=foo#get_container_info")
        ws.should_not be_nil
        ws.root("ncpus").should be_nil
        ws.root("memory").should be_nil
        ws.root("vlan").should be_nil
      end

      it "should instantiate customization" do
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_customization")
        ws.should_not be_nil
        ws.root("customization").should == EXPECTED_CUSTOMIZATION
      end

      it "should have Domain class" do
        fqname = "#{@domain}/EVMApplications/Provisioning/Domain"
        klass = MiqAeClass.find_by_fqname(fqname)
        klass.should_not be_nil
        klass.ae_instances.length.should_not == 0
        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_domains")
        ws.should_not be_nil

        domains = ws.root['domains']
        domains.should_not be_nil
        domains.should be_a_kind_of(Array)
        domains.each { |domain|
          domain.should be_a_kind_of(Hash)
          [:base_dn, :bind_dn, :bind_password, :ldap_host, :ldap_port, :user_type, :name].each { |key| domain.should have_key(key) }
        }
      end

      it "should have Network class" do
        fqname = "#{@domain}/EVMApplications/Provisioning/Network"
        klass = MiqAeClass.find_by_fqname(fqname)
        klass.should_not be_nil
        klass.ae_instances.length.should_not == 0

        ws = MiqAeEngine.instantiate("/EVMApplications/Provisioning/Information/Default#get_networks")
        ws.should_not be_nil

        networks = ws.root['networks']
        networks.should_not be_nil
        networks.should be_a_kind_of(Array)
        networks.each { |network|
          network.should be_a_kind_of(Hash)
          [:scope, :vlan, :vc_id, :dhcp_servers].each { |key| network.should have_key(key) }
          network[:dhcp_servers].should be_a_kind_of(Array)
          network[:dhcp_servers].each { |dhcp|
            dhcp.should be_a_kind_of(Hash)
            [:domain, :ip, :name].each { |key| dhcp.should have_key(key) }
            dhcp[:domain].should be_a_kind_of(Hash)
            [:base_dn, :bind_dn, :bind_password, :ldap_host, :ldap_port, :user_type, :name].each { |key| dhcp[:domain].should have_key(key) }
          }
        }
      end

    end
  end
end
