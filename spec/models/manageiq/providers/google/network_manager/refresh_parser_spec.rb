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

  before(:example) do
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

  it 'returns properly-structured hash on empty project' do
    hashes = described_class.new(ems).ems_inv_to_hashes

    expect(hashes).to eql(
      :cloud_networks             => [],
      :floating_ips               => [],
      :load_balancer_listeners    => [],
      :load_balancers             => [],
      :load_balancer_pools        => [],
      :load_balancer_pool_members => [],
      :network_ports              => [],
      :security_groups            => []
    )
  end

  it 'returns a load balancer listener from a forwarding rule' do
    set_forwarding_rules(
      connection,
      [
        instance_double(
          "Fog::Compute::Google::ForwardingRule",
          :id          => "some-id",
          :name        => "my-forwarding-rule",
          :ip_protocol => "TCP",
          :port_range  => "8080-8090",
          :target      => "https://www.googleapis.com/compute/v1/projects/#{ems.project}/regions/#{az.name}/targetPools/my-tp"
        )
      ]
    )
    set_target_pools(
      connection,
      [
        instance_double(
          "Fog::Compute::Google::TargetPool",
          :id            => "some-target-pool-id",
          :name          => "my-tp",
          :self_link     => "https://www.googleapis.com/compute/v1/projects/#{ems.project}/regions/#{az.name}/targetPools/my-tp",
          :health_checks => nil,
          :instances     => [
            "https://www.googleapis.com/compute/v1/projects/#{ems.project}/zones/#{az.name}/instances/#{vm.name}"]
        )
      ]
    )

    # Because we linked to a VM instance in the target pool, let's make sure to
    # associate an id with the link so that our returned result understands the
    # association.
    allow(connection).to receive(:get_server).with(vm.name, vm.availability_zone.name) do
      { :body => { "id" => vm.ems_ref } }
    end

    hashes = described_class.new(ems).ems_inv_to_hashes

    expect(hashes[:load_balancers]).to eql(
      [
        :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancer",
        :ems_ref => "some-id",
        :name    => "my-forwarding-rule"
      ]
    )
    expect(hashes[:load_balancer_listeners]).to eql(
      [
        :name                         => "my-forwarding-rule",
        :type                         => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerListener",
        :ems_ref                      => "some-id",
        :load_balancer_protocol       => "TCP",
        :instance_protocol            => "TCP",
        :load_balancer_port_range     => (8080..8090),
        :instance_port_range          => (8080..8090),
        :load_balancer                => hashes[:load_balancers][0],
        :load_balancer_listener_pools => [
          :load_balancer_pool         => hashes[:load_balancer_pools][0]
        ]
      ]
    )
    expect(hashes[:load_balancer_pools]).to eql(
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

  describe '#parse_port_range' do
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

  describe 'described_class#parse_vm_link' do
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

  private

  def set_forwarding_rules(connection, items)
    allow(connection).to receive(:forwarding_rules) { forwarding_rules_collection(items) }
  end

  def set_target_pools(connection, items)
    allow(connection).to receive(:target_pools) { target_pools_collection(items) }
  end

  def forwarding_rules_collection(items)
    fog_collection(items, :name)
  end

  def target_pools_collection(items)
    fog_collection(items, :name)
  end

  def fog_collection(items, get_key = nil)
    collection = double
    allow(collection).to receive(:to_a) { items }
    allow(collection).to receive(:all) { items }
    allow(collection).to receive(:select) { items.select }
    # allow lookup via get with the get_key
    items.each do |item|
      allow(collection).to receive(:get).with(item.send(get_key)) { item }
    end unless get_key.nil?

    collection
  end
end
