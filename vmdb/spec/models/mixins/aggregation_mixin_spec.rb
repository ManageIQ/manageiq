require "spec_helper"

describe AggregationMixin do
  it "#aggregate_cpu_speed" do
    cluster = FactoryGirl.create(:ems_cluster, :hosts =>
      2.times.collect do
        FactoryGirl.create(:host,
          :hardware => FactoryGirl.create(:hardware,
            :numvcpus => 2, :cores_per_socket => 4, :logical_cpus => 8, :cpu_speed => 2_999
          )
        )
      end
    )

    expect(cluster.aggregate_cpu_speed).to eq(47_984) # 2999 cpu_speed * 8 logical_cpus * 2 hardwares
  end
end
