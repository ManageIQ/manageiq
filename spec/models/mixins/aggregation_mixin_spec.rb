RSpec.describe AggregationMixin do
  let(:cpu_speed) { 2_999 * 8 }
  let(:memory)    { 2_048 }
  let(:hardware_args) do
    {
      :cpu_sockets          => 2,
      :cpu_cores_per_socket => 4,
      :cpu_total_cores      => 8,
      :cpu_speed            => 2_999,
      :disk_capacity        => 40,
      :memory_mb            => memory,
    }
  end

  # uses parameters
  describe "#aggregate_cpu_speed" do
    it "calculates a cluster" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_cpu_speed).to eq(cpu_speed * 2)
    end

    it "calculates from objects" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_cpu_speed(partial_cluster)).to eq(cpu_speed)
    end

    it "calculates from ids" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_cpu_speed(partial_cluster.map(&:id))).to eq(cpu_speed)
    end
  end

  # uses parameters
  describe "#aggregate_cpu_total_cores" do
    it "calculates a cluster" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_cpu_total_cores).to eq(8 * 2)
    end

    it "calculates from objects" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_cpu_total_cores(partial_cluster)).to eq(8)
    end

    it "calculates from ids" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_cpu_total_cores(partial_cluster.map(&:id))).to eq(8)
    end
  end

  describe "#aggregate_physical_cpus" do
    it "calculates a cluster" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_physical_cpus).to eq(2 * 2 + 1)
    end
  end

  # uses parameters
  describe "#aggregate_memory" do
    it "calculates a cluster" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_memory).to eq(memory * 2)
    end

    it "calculates from objects" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_memory(partial_cluster)).to eq(memory)
    end

    it "calculates from ids" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_memory(partial_cluster.map(&:id))).to eq(memory)
    end
  end

  describe "#aggregate_vm_cpus" do
    it "calculates a cluster" do
      cluster = cluster_3_1_vm(hardware_args)
      expect(cluster.aggregate_vm_cpus).to eq(2 * 3 + 1)
    end
  end

  describe "#aggregate_vm_memory" do
    it "calculates a cluster" do
      cluster = cluster_3_1_vm(hardware_args)
      expect(cluster.aggregate_vm_memory).to eq(memory * 3)
    end
  end

  describe "#aggregate_disk_capacity" do
    it "calculates a cluster" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_disk_capacity).to eq(40 * 2)
    end

    it "calculates from vms" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_disk_capacity(partial_cluster)).to eq(40)
    end

    it "calculates from vm ids" do
      cluster = cluster_2_1_host(hardware_args)
      partial_cluster = cluster.hosts[1..1] + cluster.hosts[2..2]
      expect(cluster.aggregate_disk_capacity(partial_cluster.map(&:id))).to eq(40)
    end
  end

  describe "aggregate_hardware" do
    it "calculates from hosts" do
      cluster = cluster_2_1_host(hardware_args)
      expect(cluster.aggregate_hardware("host", :aggregate_cpu_speed)).to eq(cpu_speed * 2)
    end
  end

  private

  def cluster_2_1_host(hardware_args)
    hosts = Array.new(2) do
      FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, hardware_args))
    end + [FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware))]
    FactoryBot.create(:ems_cluster, :hosts => hosts)
  end

  def cluster_3_1_vm(hardware_args)
    vms = Array.new(3) do
      FactoryBot.create(:vm, :hardware => FactoryBot.create(:hardware, hardware_args))
    end + [FactoryBot.create(:vm, :hardware => FactoryBot.create(:hardware))]

    FactoryBot.create(:ems_cluster, :vms => vms)
  end
end
