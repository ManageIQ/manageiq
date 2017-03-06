describe ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Runner do
  let(:ems) { FactoryGirl.create(:ems_kubernetes, :hostname => 'hostname') }

  context "#find_target" do
    require 'hawkular/hawkular_client'

    it "find a target container node" do
      target = FactoryGirl.create(:container_node, :id => 999, :name => 'the_target')
      tags = {
        'type'     => 'node',
        'nodename' => target.name
      }
      expect(described_class.find_target(tags)).to eq(target)
    end
  end
end
