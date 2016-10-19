describe ManageIQ::Providers::Openstack::InfraManager::Host do
  describe "#refresh_openstack_services" do
    let(:openstack_status_text) do
      <<-EOT
== Nova services ==
openstack-nova-api:                     active
openstack-nova-cert:                    inactive  (disabled on boot)
openstack-nova-compute:                 active
openstack-nova-network:                 inactive  (disabled on boot)
openstack-nova-scheduler:               active
openstack-nova-conductor:               active
== Glance services ==
openstack-glance-api:                   active
openstack-glance-registry:              active
openstack-glance-for-test:              active
== Keystone service ==
openstack-keystone:                     active
      EOT
    end

    let(:ssu) do
      double('ssu').tap do |ssu|
        expect(ssu).to receive(:shell_exec).with("openstack-status").and_return(openstack_status_text)
      end
    end

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        allow(host).to receive(:connect_ssh).and_yield(ssu)

        # create generic SystemService
        host.system_services << FactoryGirl.create(:system_service)
        # create OpenStack related SystemService to test against
        host.system_services << FactoryGirl.create(:system_service, :name => 'openstack-nova-api')
        # create generic Filesystem
        host.filesystems << FactoryGirl.create(:filesystem)
        # create OpenStack related Filesystems to test against
        host.filesystems << FactoryGirl.create(:filesystem, :name => '/etc/nova.conf')
        host.filesystems << FactoryGirl.create(:filesystem, :name => '/etc/nova/api.conf')

        # create HostServiceGroupOpenstack existing prior to calling HostOpenstackInfra#refresh_openstack_services
        glance = FactoryGirl.create(:host_service_group_openstack, :name => 'Glance services')
        # create glance_api and add it to both Host and HostServiceGroupOpenstack objects
        glance_api = FactoryGirl.create(:system_service, :name => 'openstack-glance-api')
        glance.system_services << glance_api
        host.system_services << glance_api
        # create glance_registry and add it to Host object only
        glance_registry = FactoryGirl.create(:system_service, :name => 'openstack-glance-registry')
        host.system_services << glance_registry

        # create glance_conf and add it both Host and HostServiceGroupOpenstack objects
        glance_conf = FactoryGirl.create(:filesystem, :name => '/etc/glance.conf')
        glance.filesystems << glance_conf
        host.filesystems << glance_conf
        # create glance_conf_2 and add it to Host object only
        glance_conf_2 = FactoryGirl.create(:filesystem, :name => '/etc/glance/2.conf')
        host.filesystems << glance_conf_2

        host.host_service_group_openstacks << glance

        # create keystone system service on host
        host.system_services << FactoryGirl.create(:system_service, :name => 'openstack-keystone')
      end
    end

    before do
      FactoryGirl.create(:host_service_group_openstack, :host => host, :name =>  'Keystone service')
    end

    context "with stubbed MiqLinux::Utils" do
      it "makes proper utils calls" do
        miq_linux_utils_double = double('MiqLinux::Utils')
        expect(miq_linux_utils_double).to receive(:parse_openstack_status).with(openstack_status_text).and_return([])
        stub_const('MiqLinux::Utils', miq_linux_utils_double)
        host.refresh_openstack_services(ssu)
      end
    end

    context "supported features" do
      before(:each) do
        host.refresh_openstack_services(ssu)
      end

      it "supports refresh_network_interfaces" do
        expect(host.supports_refresh_network_interfaces?).to be_truthy
      end
    end

    describe "host_service_group_openstacks names" do
      subject do
        host.refresh_openstack_services(ssu)
        host.host_service_group_openstacks.map(&:name)
      end

      let(:expected) do
        [
          'Nova services',
          'Glance services',
          'Keystone service',
        ]
      end

      let(:unexpected) do
        [
          'Swift services',
        ]
      end

      it { is_expected.to include(*expected) }
      it { is_expected.not_to include(*unexpected) }
    end

    describe "system_services names" do
      subject do
        host.refresh_openstack_services(ssu)
        host.system_services.map(&:name)
      end

      let(:expected) do
        [
          'openstack-nova-api',
          'openstack-glance-api',
          'openstack-glance-registry',
          'openstack-keystone',
        ]
      end

      let(:unexpected) do
        [
          'openstack-nova-compute', # was not present in Host#system_services
        ]
      end

      it { is_expected.to include(*expected) }
      it { is_expected.not_to include(*unexpected) }
    end

    describe "filesystems names" do
      subject do
        host.refresh_openstack_services(ssu)
        host.filesystems.map(&:name)
      end

      let(:expected) do
        [
          '/etc/nova.conf',
          '/etc/nova/api.conf',
          '/etc/glance.conf',
          '/etc/glance/2.conf',
        ]
      end

      it { is_expected.to include(*expected) }
    end

    describe "existing HostServiceGroupOpenstack gets updated" do
      let(:glance_host_service_group) do
        host.refresh_openstack_services(ssu)
        host.host_service_group_openstacks.where(:name => 'Glance services').first
      end

      describe "system_service names" do
        subject do
          glance_host_service_group.system_services.map(&:name)
        end

        let(:expected) do
          [
            'openstack-glance-api',
            'openstack-glance-registry',
          ]
        end

        let(:unexpected) do
          [
            'openstack-nova-compute',
            'openstack-keystone',
            'openstack-glance-for-test',
          ]
        end

        it { is_expected.to include(*expected) }
        it { is_expected.not_to include(*unexpected) }
      end

      describe "filesystem names" do
        subject do
          glance_host_service_group.filesystems.map(&:name)
        end

        let(:expected) do
          [
            '/etc/glance.conf',
            '/etc/glance/2.conf',
          ]
        end

        let(:unexpected) do
          [
            '/etc/nova.conf',
            '/etc/nova/api.conf',
          ]
        end

        it { is_expected.to include(*expected) }
        it { is_expected.not_to include(*unexpected) }
      end
    end

    it "creates association with existing SystemServices" do
      host.refresh_openstack_services(ssu)
      # we test if SystemServices with associated HostServiceGroupOpenstacks from current Host
      # are included among all SystemServices of that host
      expect(host.system_services).to include(*(host.host_service_group_openstacks.flat_map(&:system_services)))
    end

    it "creates association with existing Filesystems" do
      host.refresh_openstack_services(ssu)
      # we test if Filesystems with associated HostServiceGroupOpenstacks from current Host
      # are included among all Filesystems of that host
      expect(host.filesystems).to include(*(host.host_service_group_openstacks.flat_map(&:filesystems)))
    end
  end

  describe "Overriden auth methods for ssh fleecing," do
    let(:ext_management_system) do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryGirl.create(:ems_openstack_infra, :zone => zone).tap do |ems|
        ems.authentications << FactoryGirl.create(:authentication_ssh_keypair)
        ems.authentications << FactoryGirl.create(:authentication)
      end
    end

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.ext_management_system = ext_management_system
        host.authentications << FactoryGirl.create(:authentication_ssh_keypair_without_key)
        host.save
      end
    end

    before :each do
      allow_any_instance_of(Authentication).to receive(:raise_event)
    end

    it "#get_parent_keypair returns parent provider auth" do
      expected_auth = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
      expect(host.get_parent_keypair(:ssh_keypair)).to eq expected_auth
    end

    context "#authentication_status" do
      it "returns host's auth status if auth is there" do
        expect(host.authentication_status).to eq 'SomeMockedStatus'
      end

      it "returns status of ssh_keypair auth when credentials are defined" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'auth_key'
        host_ssh_keypair_auth.status = 'host_ssh_keypair_auth_status'
        host_ssh_keypair_auth.save
        expect(host.authentication_status).to eq host_ssh_keypair_auth.status
      end

      it "returns status of default auth when credentials are defined" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = ''
        host_ssh_keypair_auth.status = 'host_ssh_keypair_auth_status'
        host_ssh_keypair_auth.save

        host_default_auth = FactoryGirl.create(:authentication,
                                               :password => 'pass',
                                               :status   => 'host_default_auth_status')
        host_default_auth.password = 'pass'
        host_default_auth.status = 'host_default_auth_status'
        host_default_auth.save
        host.authentications << host_default_auth

        expect(host.authentication_status).to eq host_default_auth.status
      end

      it "returns status of ssh_keypair auth when both default and ssh_keypair credentials are defined" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'auth_key'
        host_ssh_keypair_auth.status = 'host_ssh_keypair_auth_status'
        host_ssh_keypair_auth.save

        host_default_auth = FactoryGirl.create(:authentication,
                                               :password => 'pass',
                                               :status   => 'host_default_auth_status')
        host.authentications << host_default_auth

        expect(host.authentication_status).to eq host_ssh_keypair_auth.status
      end

      it "checks ws and ipmi credentials don't affect the host.authentication_status" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'auth_key'
        host_ssh_keypair_auth.status = 'host_ssh_keypair_auth_status'
        host_ssh_keypair_auth.save

        host.authentications << FactoryGirl.create(:authentication_ipmi, :status => 'host_ipmi_auth_status')
        host.authentications << FactoryGirl.create(:authentication_ws, :status => 'host_ws_auth_status')
        host_default_auth = FactoryGirl.create(:authentication, :status => 'host_default_auth_status')
        host.authentications << host_default_auth

        expect(host.authentication_status).to eq host_ssh_keypair_auth.status

        host_ssh_keypair_auth.auth_key = ''
        host_ssh_keypair_auth.save
        host.reload

        expect(host.authentication_status).to eq host_default_auth.status
      end

      it "returns 'None' if host's auth is nil" do
        # Remove the host's auth record
        host.authentications.where(:authtype => :ssh_keypair).first.destroy
        host.reload
        expect(host.authentication_status).to eq 'None'
      end
    end

    context "#ssh_users_and_passwords" do
      it "returns authentication_best_fit" do
        auth        = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
        expected_ret = auth.userid, nil, nil, nil, {:key_data => auth.auth_key, :passwordless_sudo => true}

        expect(host.ssh_users_and_passwords).to eq expected_ret
      end

      it "passes passwordless sudo parameter if user is not 'root'" do
        # Switch to auth with root user
        ext_management_system.authentications.where(:authtype => :ssh_keypair).first.destroy
        ext_management_system.authentications << FactoryGirl.create(:authentication_ssh_keypair_root)

        auth = ext_management_system.authentications.where(:authtype => :ssh_keypair).first

        expected_ret = auth.userid, nil, nil, nil, {:key_data => auth.auth_key, :passwordless_sudo => false}

        host.reload
        expect(host.ssh_users_and_passwords).to eq expected_ret
      end
    end

    context "#authentication_best_fit" do
      it "defaults to parent provider ssh_keypair auth" do
        ems_auth  = ext_management_system.authentications.where(:authtype => :ssh_keypair).first

        expect(host.authentication_best_fit).to eq ems_auth
      end

      it "checks that if host's auth_key and password is nil, parent auth is returned" do
        ems_auth  = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first

        host_default_auth = FactoryGirl.create(:authentication)
        host_default_auth.password = ''
        host_default_auth.save
        host.authentications << host_default_auth

        expect(host_ssh_keypair_auth.auth_key).to be_nil
        expect(host.authentication_best_fit).to eq ems_auth
      end

      it "checks that if host's ssh_keypair auth_key is not nil, host's auth is returned" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'host_private_key_content'
        host_ssh_keypair_auth.save

        expect(host.authentication_best_fit).to eq host_ssh_keypair_auth
      end

      it "checks that if host's default auth password is not nil, host's auth is returned" do
        host_default_auth = FactoryGirl.create(:authentication)
        host.authentications << host_default_auth

        expect(host.authentication_best_fit).to eq host_default_auth
      end

      it "checks that ssh keypair_takes precedence over default auth" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'host_private_key_content'
        host_ssh_keypair_auth.save

        host_auth = FactoryGirl.create(:authentication)
        host.authentications << host_auth

        expect(host.authentication_best_fit).to eq host_ssh_keypair_auth
      end

      it "checks ws and ipmi credentials don't affect the host.authentication_best_fit" do
        host_ssh_keypair_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_ssh_keypair_auth.auth_key = 'auth_key'
        host_ssh_keypair_auth.status = 'host_ssh_keypair_auth_status'
        host_ssh_keypair_auth.save

        host.authentications << FactoryGirl.create(:authentication_ipmi, :status => 'host_ipmi_auth_status')
        host.authentications << FactoryGirl.create(:authentication_ws, :status => 'host_ws_auth_status')
        host.authentications << FactoryGirl.create(:authentication, :status => 'host_default_auth_status')

        # All credentials filled, ssh_keypair takes precedence
        expect(host.authentication_best_fit).to eq host_ssh_keypair_auth

        host_ssh_keypair_auth.auth_key = ''
        host_ssh_keypair_auth.save
        host.reload

        host_default_auth = host.authentications.where(:authtype => :default).first
        # Only default password filled
        expect(host.authentication_best_fit).to eq host_default_auth

        host_default_auth.password = ''
        host_default_auth.save
        host.reload

        ems_auth  = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
        # ssh_keypair nor default credetials are filled on host, taking parent auth
        expect(host.authentication_best_fit).to eq ems_auth
      end
    end

    context "#update_ssh_auth_status!" do
      context "when ssh connection causes exception," do
        before :each do
          allow(host).to receive(:verify_credentials_with_ssh) { raise "some error" }
        end

        it "sets auth to 'Error' state if credentials exists" do
          host_auth = host.authentications.where(:authtype => :ssh_keypair).first
          expect(host_auth.status).to eq("SomeMockedStatus")
          # Update status and observe it changes to error
          host.update_ssh_auth_status!
          host_auth.reload
          expect(host_auth.status).to eq("Error")
        end

        it "sets auth to 'Incomplete' state when hostname or credentials are missing" do
          # Remove the auth and observe the state is not error but none
          ext_management_system.authentications.where(:authtype => :ssh_keypair).first.destroy
          host.reload
          # Update status and observe it changes to none
          host.update_ssh_auth_status!
          expect(host.authentications.where(:authtype => :ssh_keypair).first.status).to eq("Incomplete")
        end
      end

      context "when ssh connection succeeds and verification returns true," do
        before :each do
          allow(host).to receive(:verify_credentials_with_ssh).and_return(true)
        end

        it "sets auth to valid, when credentials verification succeeds" do
          # Update status and observe it changes to Valid
          host.update_ssh_auth_status!
          expect(host.authentications.where(:authtype => :ssh_keypair).first.status).to eq("Valid")
        end

        it "creates new auth record for storing state if there is not any" do
          host.authentications.where(:authtype => :ssh_keypair).first.destroy
          # Check we have removed host's auth
          expect(host.authentications.where(:authtype => :ssh_keypair)).to eq([])
          # Update status and observe it creates new auth with Valid state
          host.reload
          host.update_ssh_auth_status!
          host.reload
          expect(host.authentications.where(:authtype => :ssh_keypair).first.status).to eq("Valid")
        end
      end
    end
  end

  describe "ironic tasks" do
    let(:ext_management_system) do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryGirl.create(:ems_openstack_infra, :zone => zone)
    end

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.ext_management_system = ext_management_system
        host.save
      end
    end

    it "check X_queue tasks are queued" do
      expect(MiqQueue.where(:method_name => "introspect").count).to eq(0)
      host.introspect_queue
      expect(MiqQueue.where(:method_name => "introspect").count).to eq(1)

      expect(MiqQueue.where(:method_name => "provide").count).to eq(0)
      host.provide_queue
      expect(MiqQueue.where(:method_name => "provide").count).to eq(1)

      expect(MiqQueue.where(:method_name => "manageable").count).to eq(0)
      host.manageable_queue
      expect(MiqQueue.where(:method_name => "manageable").count).to eq(1)

      expect(MiqQueue.where(:method_name => "destroy_ironic").count).to eq(0)
      host.destroy_ironic_queue
      expect(MiqQueue.where(:method_name => "destroy_ironic").count).to eq(1)
    end

    it "check task executes and queues refresh if success" do
      response = double("response")
      expect(response).to receive(:body).at_least(1).times { {"state" => "SUCCESS", "id" => 1} }
      expect(response).to receive(:status).and_return(202)
      workflow_service = double("workflow_service")
      expect(workflow_service).to receive(:create_execution).at_least(1).times { response }
      baremetal_service = double("baremetal_service")
      expect(baremetal_service).to receive(:set_node_provision_state) { response }
      openstack_handle = double("openstack handle")
      expect(openstack_handle).to receive(:detect_workflow_service).at_least(1).times { workflow_service }
      expect(openstack_handle).to receive(:detect_baremetal_service) { baremetal_service }
      allow(ext_management_system).to receive(:openstack_handle).and_return(openstack_handle)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(0)

      task = FactoryGirl.create(:miq_task)
      host.introspect(task.id)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(1)

      MiqQueue.all.map(&:delete)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(0)
      task = FactoryGirl.create(:miq_task)
      host.provide(task.id)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(1)

      MiqQueue.all.map(&:delete)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(0)
      task = FactoryGirl.create(:miq_task)
      host.manageable(task.id)
      expect(task.status).to eq("Ok")
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(1)
    end

    it "check task executes and queues destroy_queue if success" do
      baremetal_service = double("baremetal_service")
      expect(baremetal_service).to receive(:delete_node) { double(:status => 204) }
      openstack_handle = double("openstack handle")
      expect(openstack_handle).to receive(:detect_baremetal_service) { baremetal_service }
      allow(ext_management_system).to receive(:openstack_handle).and_return(openstack_handle)
      expect(MiqQueue.where(:method_name => "destroy").count).to eq(0)

      host.destroy_ironic
      expect(MiqQueue.where(:method_name => "destroy").count).to eq(1)
    end

    it "check ironic_set_power_state is queued" do
      expect(MiqQueue.where(:method_name => "ironic_set_power_state").count).to eq(0)
      host.ironic_set_power_state_queue
      expect(MiqQueue.where(:method_name => "ironic_set_power_state").count).to eq(1)
    end

    it "check ironic_set_power_state executes and queues refresh if success" do
      baremetal_service = double("baremetal_service")
      expect(baremetal_service).to receive(:set_node_power_state) { double(:status => 202) }
      openstack_handle = double("openstack handle")
      expect(openstack_handle).to receive(:detect_baremetal_service) { baremetal_service }
      allow(ext_management_system).to receive(:openstack_handle).and_return(openstack_handle)
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(0)

      host.ironic_set_power_state
      expect(MiqQueue.where(:method_name => "refresh").count).to eq(1)
    end
  end
end
