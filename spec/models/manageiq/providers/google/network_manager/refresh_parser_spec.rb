require 'digest'

describe ManageIQ::Providers::Google::NetworkManager::RefreshParser do
  let(:ems) { FactoryGirl.create(:ems_google, :project => "manageiq-dev") }
  let(:az) { FactoryGirl.create(:availability_zone_google) }
  let(:vm) do
    FactoryGirl.create(:vm_google,
                       :ext_management_system => ems,
                       :ems_ref               => 123,
                       :availability_zone     => az)
  end
  # These tests use some fairly aggressive stubbing. Specifically, all of the
  # fog calls are stubbed out. This allows us to test the refresh logic without
  # resorting to VCR casettes.
  let(:connection) { double }

  context 'google project is empty of resources' do
    subject { described_class.new(ems).ems_inv_to_hashes }
    before do
      allow(ems).to receive(:connect) { connection }
      # Install some reasonable defaults, with all collections being empty.
      allow(connection).to receive(:project) { ems.project }
      allow(connection).to receive(:networks) { fog_collection([]) }
      allow(connection).to receive(:firewalls) { fog_collection([]) }
      allow(connection).to receive(:servers) { fog_collection([]) }
      allow(connection).to receive(:addresses) { fog_collection([]) }
      allow(connection).to receive(:forwarding_rules) { fog_collection([]) }
      allow(connection).to receive(:target_pools) { fog_collection([]) }
    end

    describe "#ems_inv_to_hashes" do
      it 'returns properly-structured hash' do
        expect(subject).to eql(
          :cloud_networks              => [],
          :floating_ips                => [],
          :load_balancer_listeners     => [],
          :load_balancers              => [],
          :load_balancer_pools         => [],
          :load_balancer_pool_members  => [],
          :load_balancer_health_checks => [],
          :network_ports               => [],
          :security_groups             => []
        )
      end
    end
  end

  context 'google project contains a forwarding rule with a backend service of two vms' do
    subject { described_class.new(ems).ems_inv_to_hashes }

    before do
      allow(ems).to receive(:connect) { connection }
      allow(connection).to receive(:project) { ems.project }
      allow(connection).to receive(:networks) { fog_collection([]) }
      allow(connection).to receive(:firewalls) { fog_collection([]) }
      allow(connection).to receive(:servers) { fog_collection([]) }
      allow(connection).to receive(:addresses) { fog_collection([]) }
      allow(connection).to receive(:forwarding_rules) do
        fog_collection(
          [
            instance_double(
              "Fog::Compute::Google::ForwardingRule",
              :id          => "some-id",
              :name        => "my-forwarding-rule",
              :ip_protocol => "TCP",
              :port_range  => "8080-8090",
              :target      => "https://www.googleapis.com/compute/v1/projects/#{ems.project}/regions/#{az.name}/targetPools/my-tp"
            )
          ])
      end
      allow(connection).to receive(:target_pools) do
        fog_collection(
          [
            instance_double(
              "Fog::Compute::Google::TargetPool",
              :id            => "some-target-pool-id",
              :name          => "my-tp",
              :self_link     => "https://www.googleapis.com/compute/v1/projects/#{ems.project}/regions/#{az.name}/targetPools/my-tp",
              :health_checks => ["https://www.googleapis.com/compute/v1/projects/#{ems.project}/global/httpHealthChecks/my-healthcheck"],
              :instances     => [
                "https://www.googleapis.com/compute/v1/projects/#{ems.project}/zones/#{az.name}/instances/#{vm.name}"],
              :get_health    => {
                "https://www.googleapis.com/compute/v1/projects/#{ems.project}/zones/#{az.name}/instances/#{vm.name}" => [
                  "instance"    => "https://www.googleapis.com/compute/v1/projects/#{ems.project}/zones/#{az.name}/instances/#{vm.name}",
                  "healthState" => "HEALTHY"
                ]
              }
            )
          ])
      end
      allow(connection).to receive(:http_health_checks) do
        fog_collection(
          [
            instance_double(
              "Fog::Compute::Google::HttpHealthCheck",
              :id                  => "some-healthcheck-id",
              :name                => "my-healthcheck",
              :request_path        => "/foo",
              :port                => 80,
              :check_interval_sec  => 5,
              :timeout_sec         => 6,
              :unhealthy_threshold => 7,
              :healthy_threshold   => 8)
          ])
      end

      # Because we linked to a VM instance in the target pool, let's make sure to
      # associate an id with the link so that our returned result understands the
      # association.
      allow(connection).to receive(:get_server).with(vm.name, vm.availability_zone.name) do
        { :body => { "id" => vm.ems_ref } }
      end
    end

    describe "#ems_inv_to_hashes" do
      it "returns a load balancer" do
        expect(subject[:load_balancers]).to eql(
          [
            :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancer",
            :ems_ref => "some-id",
            :name    => "my-forwarding-rule"
          ]
        )
      end

      it "returns a load balancer listener" do
        expect(subject[:load_balancer_listeners]).to eql(
          [
            :name                         => "my-forwarding-rule",
            :type                         => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerListener",
            :ems_ref                      => "some-id",
            :load_balancer_protocol       => "TCP",
            :instance_protocol            => "TCP",
            :load_balancer_port_range     => (8080..8090),
            :instance_port_range          => (8080..8090),
            :load_balancer                => subject[:load_balancers][0],
            :load_balancer_listener_pools => [
              :load_balancer_pool         => subject[:load_balancer_pools][0]
            ]
          ]
        )
      end

      it "returns a load balancer pool" do
        expect(subject[:load_balancer_pools]).to eql(
          [
            :type                            => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerPool",
            :ems_ref                         => "some-target-pool-id",
            :name                            => "my-tp",
            :load_balancer_pool_member_pools => [
              :load_balancer_pool_member => {
                :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerPoolMember",
                :ems_ref => Digest::MD5.base64digest(
                  "https://www.googleapis.com/compute/v1/projects/#{ems.project}/zones/#{az.name}/instances/#{vm.name}"),
                :vm      => vm
              }
            ]
          ]
        )
      end
      it "returns a load balancer health check" do
        expect(subject[:load_balancer_health_checks]).to eql(
          [
            :name                               => "my-healthcheck",
            :ems_ref                            => "some-id_some-target-pool-id_some-healthcheck-id",
            :type                               => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerHealthCheck",
            :protocol                           => "HTTP",
            :port                               => 80,
            :url_path                           => "/foo",
            :interval                           => 5,
            :timeout                            => 6,
            :unhealthy_threshold                => 7,
            :healthy_threshold                  => 8,
            :load_balancer                      => subject[:load_balancers][0],
            :load_balancer_listener             => subject[:load_balancer_listeners][0],
            :load_balancer_health_check_members => [
              {
                :load_balancer_pool_member => subject[:load_balancer_pools][0][:load_balancer_pool_member_pools][0][:load_balancer_pool_member],
                :status                    => "InService",
                :status_reason             => ""
              }
            ]
          ]
        )
      end
    end
  end

  describe '::parse_port_range' do
    it 'treats a single port as a single port range' do
      expect(described_class.parse_port_range("80")).to eql(80..80)
    end

    it 'treats port range as a port range' do
      expect(described_class.parse_port_range("100-123")).to eql(100..123)
    end

    it 'treats an empty string as the entire tcp/udp port range' do
      expect(described_class.parse_port_range("")).to eql(0..65_535)
    end
  end

  describe '::parse_vm_link' do
    it 'does not match invalid link urls' do
      expect(described_class.parse_vm_link("")).to eql(nil)
      expect(
        described_class.parse_vm_link(
          "https://example.com/compute/v1/projects/foo/zones/bar/instances/baz")).to eql(nil)
      expect(
        described_class.parse_vm_link(
          "https://www.googleapis.com/compute/v1/projects/foo/zones/bar/instances/baz/bam/boom")).to eql(nil)
    end

    it 'does match valid link url' do
      vm_link = "https://www.googleapis.com/compute/v1/projects/foo/zones/bar/instances/baz"
      expect(described_class.parse_vm_link(vm_link)).to eql(
        :project  => "foo",
        :zone     => "bar",
        :instance => "baz"
      )
    end
  end

  def fog_collection(items)
    collection = double
    allow(collection).to receive(:to_a) { items }
    allow(collection).to receive(:all) { items }
    allow(collection).to receive(:select) { items.select }
    # allow lookup via get with the :name key
    items.each do |item|
      allow(collection).to receive(:get).with(item.send(:name)) { item }
    end

    collection
  end
end
