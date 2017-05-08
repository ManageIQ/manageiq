require 'metadata/linux/LinuxUtils'

describe MiqLinux::Utils do
  describe '#parse_openstack_status' do
    let(:text) do
      <<EOS
openstack-nova-api:                     active
openstack-nova-cert:                    inactive  (disabled on boot)
openstack-nova-compute:                 active
openstack-nova-network:                 inactive  (disabled on boot)
openstack-nova-scheduler:               active
openstack-nova-conductor:               active
openstack-glance-api:                   active
openstack-glance-registry:              active
openstack-keystone:                     active
openstack-swift-proxy:                  active
openstack-swift-account:                active
openstack-swift-container:              active
openstack-swift-object:                 active
openstack-ceilometer-api:               active
openstack-ceilometer-central:           active
openstack-ceilometer-compute:           inactive  (disabled on boot)
openstack-ceilometer-collector:         active
openstack-ceilometer-alarm-notifier:    active
openstack-ceilometer-alarm-evaluator:   active
openstack-ceilometer-notification:      active
openstack-heat-api:                     active
openstack-heat-api-cfn:                 active
openstack-heat-api-cloudwatch:          active
openstack-heat-engine:                  active
EOS
    end
    let(:subject) { MiqLinux::Utils.parse_openstack_status(text) }

    it "should return Array" do
      is_expected.to be_a Array
    end

    it "should have 6 OpenStack services" do
      expect(subject.count).to be_equal 6
    end

    %w(Nova Glance Keystone Swift Ceilometer Heat).map do |service|
      it "should have contain correct OpenStack #{service} service" do
        expect(subject.count { |service_hash| service_hash['name'].include?(service) }).to be_equal 1
      end
    end

    describe "Nova services" do
      let(:subject) do
        MiqLinux::Utils.parse_openstack_status(text).find { |service| service['name'].include?('Nova') }['services']
      end

      it "should have 6 services total" do
        expect(subject.count).to be_equal 6
      end

      it "should have 4 active services" do
        expect(subject.count { |service| service['active'] }).to be_equal 4
      end

      it "should have 2 inactive services" do
        expect(subject.count { |service| !service['active'] }).to be_equal 2
      end
    end
  end
end
