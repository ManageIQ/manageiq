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

        host.host_service_group_openstacks << glance

        # create keystone system service on host
        host.system_services << FactoryGirl.create(:system_service, :name => 'openstack-keystone')
      end
    end

    before do
      HostServiceGroupOpenstack.create(:host => host, :name => 'Keystone service')
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
    end

    it "creates association with existing SystemServices" do
      host.refresh_openstack_services(ssu)
      # we test if SystemServices with associated HostServiceGroupOpenstacks from current Host
      # are included among all SystemServices of that host
      host.system_services.should include(*(host.host_service_group_openstacks.flat_map(&:system_services)))
    end
  end
end
