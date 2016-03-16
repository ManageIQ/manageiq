require_migration

describe InlineEmsId do
  let(:container_stub) { migration_stub(:Container) }
  let(:container_group_stub) { migration_stub(:ContainerGroup) }
  let(:container_definition_stub) { migration_stub(:ContainerDefinition) }
  let(:container_group) { container_group_stub.create!(:ems_id => 23) }

  migration_context :up do
    it 'it sets the value of container.ems_id to the value of container.container_group.ems_id' do
      container = container_stub.create!(
        :container_group => container_group_stub.create!(
          :ems_id => 23
        )
      )
      migrate
      expect(container.reload.ems_id).to eq(23)
    end

    it 'it sets the value of container.ems_id to the value of container_definition.container_group.ems_id' do
      container_definition = container_definition_stub.create!(
        :container_group => container_group_stub.create!(
          :ems_id => 47
        )
      )
      migrate
      expect(container_definition.reload.ems_id).to eq(47)
    end
  end
end
