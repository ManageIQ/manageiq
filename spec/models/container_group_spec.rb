RSpec.describe ContainerGroup do
  subject { FactoryBot.create(:container_group) }

  include_examples "MiqPolicyMixin"

  it "has container volumes and pods" do
    pvc = FactoryBot.create(
      :persistent_volume_claim,
      :name => "test_claim"
    )

    group = FactoryBot.create(
      :container_group,
      :name => "group",
    )

    ems = FactoryBot.create(
      :ems_kubernetes,
      :id   => group.id,
      :name => "ems"
    )

    FactoryBot.create(
      :container_volume,
      :name                    => "container_volume",
      :type                    => 'ContainerVolume',
      :parent                  => group,
      :persistent_volume_claim => pvc
    )

    FactoryBot.create(
      :persistent_volume,
      :name                    => "persistent_volume0",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    FactoryBot.create(
      :persistent_volume,
      :name                    => "persistent_volume1",
      :parent                  => ems,
      :persistent_volume_claim => pvc
    )

    assert_pod_to_pv_relationships(group)
  end

  context "#ready_condition_status" do
    let(:condition_ready) { FactoryBot.create(:container_condition, :container_entity => container_group, :name => "Ready") }
    let(:condition_other) { FactoryBot.create(:container_condition, :container_entity => container_group, :name => "Other") }
    let(:container_group) { FactoryBot.create(:container_group) }

    it "preloads the conditions" do
      condition_other
      cr = condition_ready
      cg = ContainerGroup.includes(:ready_condition_status).references(:ready_condition_status).find_by(:id => container_group.id)

      expect { expect(cg.ready_condition).to eq(cr) }.to_not make_database_queries
    end

    it "handles non-preloaded conditions" do
      condition_other
      cr = condition_ready
      cg = ContainerGroup.find_by(:id => container_group.id)
      expect { expect(cg.ready_condition).to eq(cr) }.to make_database_queries(:count => 1)
    end
  end

  def assert_pod_to_pv_relationships(group)
    expect(group.persistent_volume_claim.first.name).to eq("test_claim")
    expect(group.persistent_volume_claim.count).to eq(1)
    expect(group.persistent_volumes.first.name).to eq("persistent_volume0")
    expect(group.persistent_volumes.second.name).to eq("persistent_volume1")
    expect(group.persistent_volumes.count).to eq(2)
  end
end
