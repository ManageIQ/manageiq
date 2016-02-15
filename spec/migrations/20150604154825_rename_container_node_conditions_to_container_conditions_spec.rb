require_migration

describe RenameContainerNodeConditionsToContainerConditions do
  class RenameContainerNodeConditionsToContainerConditions::ContainerNodeCondition < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  let(:container_node_condition_stub) { migration_stub(:ContainerNodeCondition)}
  let(:container_condition_stub)      { migration_stub(:ContainerCondition) }

  migration_context :up do
    it "defaults all container_entity_type to 'ContainerNode'" do
      cnc = container_node_condition_stub.create!

      migrate

      cc = container_condition_stub.find_by(:id => cnc.id)
      expect(cc.container_entity_type).to eq("ContainerNode")
    end
  end

  migration_context :down do
    it "removes all 'ContainerGroup' conditions" do
      cc_node  = container_condition_stub.create!(:container_entity_type => 'ContainerNode')
      cc_group = container_condition_stub.create!(:container_entity_type => 'ContainerGroup')

      migrate

      cnc_node = container_node_condition_stub.find_by(:id => cc_node.id)
      expect(cnc_node).to_not be_nil

      cnc_group = container_node_condition_stub.find_by(:id => cc_group.id)
      expect(cnc_group).to be_nil
    end
  end
end
