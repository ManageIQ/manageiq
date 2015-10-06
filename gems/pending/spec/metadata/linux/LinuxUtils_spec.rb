require "spec_helper"
require 'metadata/linux/LinuxUtils'

describe MiqLinux::Utils do
  describe '#parse_openstack_status' do
    let(:text) do
      <<EOS
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
== Keystone service ==
openstack-keystone:                     active
== Horizon service ==
openstack-dashboard:                    active
== neutron services ==
neutron-server:                         active
neutron-dhcp-agent:                     active
neutron-l3-agent:                       inactive  (disabled on boot)
neutron-metadata-agent:                 inactive  (disabled on boot)
neutron-openvswitch-agent:              active
== Swift services ==
openstack-swift-proxy:                  active
openstack-swift-account:                active
openstack-swift-container:              active
openstack-swift-object:                 active
== Ceilometer services ==
openstack-ceilometer-api:               active
openstack-ceilometer-central:           active
openstack-ceilometer-compute:           inactive  (disabled on boot)
openstack-ceilometer-collector:         active
openstack-ceilometer-alarm-notifier:    active
openstack-ceilometer-alarm-evaluator:   active
openstack-ceilometer-notification:      active
== Heat services ==
openstack-heat-api:                     active
openstack-heat-api-cfn:                 active
openstack-heat-api-cloudwatch:          active
openstack-heat-engine:                  active
== Support services ==
mysqld:                                 inactive  (disabled on boot)
openvswitch:                            active
dbus:                                   active
rabbitmq-server:                        active
memcached:                              active
== Keystone users ==
Warning keystonerc not sourced
EOS
    end
    let(:subject) { MiqLinux::Utils.parse_openstack_status(text) }

    it "should return Array" do
      should be_a Array
    end

    # we omit Keystone users section
    it "should have 9 OpenStack services" do
      subject.count.should be_equal 9
    end

    %w(Nova Glance Keystone Swift neutron Ceilometer Heat Support).map do |service|
      it "should have contain correct OpenStack #{service} service" do
        subject.count { |service_hash| service_hash['name'].include?(service) }.should be_equal 1
      end
    end

    describe "Nova services" do
      let(:subject) do
        MiqLinux::Utils.parse_openstack_status(text).find { |service| service['name'].include?('Nova') }['services']
      end

      it "should have 6 services total" do
        subject.count.should be_equal 6
      end

      it "should have 4 active services" do
        subject.count { |service| service['active'] }.should be_equal 4
      end

      it "should have 2 inactive services" do
        subject.count { |service| !service['active'] }.should be_equal 2
      end
    end
  end
end
