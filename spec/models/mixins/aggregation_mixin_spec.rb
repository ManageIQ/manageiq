require "spec_helper"

describe AggregationMixin do
  it "aggregate host attributes" do
    cluster = FactoryGirl.create(:ems_cluster, :hosts =>
      2.times.collect do
        FactoryGirl.create(:host,
                           :hardware => FactoryGirl.create(:hardware,
                                                           :numvcpus         => 2,
                                                           :cores_per_socket => 4,
                                                           :logical_cpus     => 8,
                                                           :cpu_speed        => 2_999,
                                                           :disk_capacity    => 40
                                                          )
                          )
      end
                                )

    expect(cluster.aggregate_cpu_speed).to eq(47_984) # 2999 cpu_speed * 8 logical_cpus * 2 hardwares
    expect(cluster.aggregate_disk_capacity).to eq(80)
  end
end
