require 'shared/presenters/tree_node/common'

describe TreeNode::ServiceTemplate do
  subject { described_class.new(object, nil, {}) }
  let(:tenant) { FactoryGirl.create(:tenant) }
  %i(
    service_template
    service_template_ansible_tower
    service_template_orchestration
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory, :name => 'foo', :tenant => tenant) }

      include_examples 'TreeNode::Node#key prefix', 'st-'
      include_examples 'TreeNode::Node#image', '100/service_template.png'

      describe '#title' do
        it 'returns with the catalog name and tenant name as a suffix' do
          expect(subject.title).to eq("#{object.name} (#{object.tenant.name})")
        end
      end
    end
  end
end
