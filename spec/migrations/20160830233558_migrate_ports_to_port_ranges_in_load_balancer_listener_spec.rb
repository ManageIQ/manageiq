require_migration

describe MigratePortsToPortRangesInLoadBalancerListener do
  let(:load_balancer_listener_stub) { migration_stub(:LoadBalancerListener) }

  migration_context :up do
    it 'migrate load_balancer_port to load_balancer_port_range when load_balancer_port set' do
      st = load_balancer_listener_stub.create!(:load_balancer_port => 443)

      migrate
      st.reload

      expect(st.load_balancer_port_range.to_a).to eq([443])
      expect(st.load_balancer_port).to be_nil
    end

    it 'does not update load_balancer_port_range when load_balancer_port is nil' do
      st = load_balancer_listener_stub.create!(:load_balancer_port => nil)

      migrate

      expect(st.reload.load_balancer_port_range).to be_nil
    end

    it 'migrates instance_port to instance_port_range when instance_port is set' do
      st = load_balancer_listener_stub.create!(:instance_port => 45)

      migrate
      st.reload

      expect(st.instance_port_range.to_a).to eq([45])
      expect(st.instance_port).to be_nil
    end

    it 'does not update instance_port_range when instance_port is nil' do
      st = load_balancer_listener_stub.create!(:instance_port => nil)

      migrate

      expect(st.reload.instance_port_range).to be_nil
    end
  end

  migration_context :down do
    it 'migrates load_balancer_port_range to load_balancer_port when load_balancer_port_range is a single port' do
      st = load_balancer_listener_stub.create!(:load_balancer_port_range => 443..443)

      migrate
      st.reload

      expect(st.load_balancer_port).to be(443)
      expect(st.load_balancer_port_range).to be_nil
    end

    it 'skips migrating load_balancer_port_range when range is multiple ports' do
      st = load_balancer_listener_stub.create!(:load_balancer_port_range => 500..699)

      migrate
      st.reload

      expect(st.load_balancer_port).to be_nil
      expect(st.load_balancer_port_range).to be_nil
    end

    it 'does not update load_balancer_port when load_balancer_port_range is nil' do
      st = load_balancer_listener_stub.create!(:load_balancer_port_range => nil)

      migrate

      expect(st.load_balancer_port).to be_nil
    end

    it 'migrates instance_port_range to instance_port when instance_port_range is a single port' do
      st = load_balancer_listener_stub.create!(:instance_port_range => 443..443)

      migrate
      st.reload

      expect(st.instance_port).to be(443)
      expect(st.instance_port_range).to be_nil
    end

    it 'skips migrating instance_port_range when range is multiple ports' do
      st = load_balancer_listener_stub.create!(:instance_port_range => 500..699)

      migrate
      st.reload

      expect(st.instance_port).to be_nil
      expect(st.instance_port_range).to be_nil
    end

    it 'does not update instance_port when instance_port_range is nil' do
      st = load_balancer_listener_stub.create!(:instance_port_range => nil)

      migrate

      expect(st.instance_port).to be_nil
    end
  end
end
