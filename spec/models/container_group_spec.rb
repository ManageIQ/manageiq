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
      :name => "group"
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
    let(:condition_ready) { FactoryBot.create(:container_condition, :container_entity => container_group, :name => "Ready", :status => "Good") }
    let(:condition_other) { FactoryBot.create(:container_condition, :container_entity => container_group, :name => "Other") }
    let(:container_group) { FactoryBot.create(:container_group) }

    it "handles no container_conditions (select and direct)" do
      condition_other

      subj = described_class.where(:id => container_group.id)
      expect(subj.first.ready_condition_status).to eq("None")
      expect(subj.select(:ready_condition_status).first.ready_condition_status).to eq("None")
    end

    it "selects ready_condition_status" do
      condition_ready
      condition_other

      subj = described_class.where(:id => container_group.id)
      expect(subj.first.ready_condition_status).to eq(condition_ready.status)
      expect(subj.select(:ready_condition_status).first.ready_condition_status).to eq(condition_ready.status)
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
