require "spec_helper"

describe HostOpenstackInfra do
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
        ssu.should_receive(:shell_exec).with("openstack-status").and_return(openstack_status_text)
      end
    end

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.stub(:connect_ssh).and_yield(ssu)

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
        miq_linux_utils_double.should_receive(:parse_openstack_status).with(openstack_status_text).and_return([])
        stub_const('MiqLinux::Utils', miq_linux_utils_double)
        host.refresh_openstack_services(ssu)
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

      it { should include(*expected) }
      it { should_not include(*unexpected) }
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

      it { should include(*expected) }
      it { should_not include(*unexpected) }
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

      it { should include(*expected) }
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

        it { should include(*expected) }
        it { should_not include(*unexpected) }
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

        it { should include(*expected) }
        it { should_not include(*unexpected) }
      end
    end

    it "creates association with existing SystemServices" do
      host.refresh_openstack_services(ssu)
      # we test if SystemServices with associated HostServiceGroupOpenstacks from current Host
      # are included among all SystemServices of that host
      host.system_services.should include(*(host.host_service_group_openstacks.flat_map(&:system_services)))
    end

    it "creates association with existing Filesystems" do
      host.refresh_openstack_services(ssu)
      # we test if Filesystems with associated HostServiceGroupOpenstacks from current Host
      # are included among all Filesystems of that host
      host.filesystems.should include(*(host.host_service_group_openstacks.flat_map(&:filesystems)))
    end
  end

  describe "Overriden auth methods for ssh fleecing" do
    let(:ext_management_system) do
      FactoryGirl.create(:ems_openstack_infra).tap do |ems|
        ems.authentications << FactoryGirl.create(:authentication_ssh_keypair)
        ems.authentications << FactoryGirl.create(:authentication)
      end
    end

    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.ext_management_system = ext_management_system
        host.authentications << FactoryGirl.create(:authentication_ssh_keypair_without_key)
      end
    end

    it "#get_parent_keypair returns parent provider auth" do
      expected_auth = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
      expect(host.get_parent_keypair(:ssh_keypair)).to eq expected_auth
    end

    context "#authentication_status" do
      it "returns host's auth status if auth is there" do
        expect(host.authentication_status).to eq 'Valid'
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

        expect(host.ssh_users_and_passwords).to eq expected_ret
      end
    end

    context "#authentication_best_fit" do
      it "defaults to parent provider ssh_keypair auth" do
        ems_auth  = ext_management_system.authentications.where(:authtype => :ssh_keypair).first

        expect(host.authentication_best_fit).to eq ems_auth
      end

      it "checks that if host's auth_key is nil, parent auth is returned" do
        ems_auth  = ext_management_system.authentications.where(:authtype => :ssh_keypair).first
        host_auth = host.authentications.where(:authtype => :ssh_keypair).first

        expect(host_auth.auth_key).to be_nil
        expect(host.authentication_best_fit(:ssh_keypair)).to eq ems_auth
      end

      it "checks that if host's auth_key is not nil, host's auth is returned" do
        host_auth = host.authentications.where(:authtype => :ssh_keypair).first
        host_auth.auth_key = 'host_private_key_content'
        host_auth.save

        expect(host.authentication_best_fit(:ssh_keypair)).to eq host_auth
      end
    end
  end
end
