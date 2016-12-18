require 'shared/presenters/tree_node/common'

describe TreeNode::ServiceTemplateCatalog do
  subject { described_class.new(object, nil, {}) }
  let(:object) do
    tenant = FactoryGirl.create(:tenant)
    FactoryGirl.create(:service_template_catalog, :name => 'foo', :tenant => tenant)
  end

  include_examples 'TreeNode::Node#key prefix', 'stc-'
  include_examples 'TreeNode::Node#image', '100/service_template_catalog.png'

  describe '#title' do
    it 'returns with the catalog name and tenant name as a suffix' do
      expect(subject.title).to eq("#{object.name} (#{object.tenant.name})")
    end
  end
end
