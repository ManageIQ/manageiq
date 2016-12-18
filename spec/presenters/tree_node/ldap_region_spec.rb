require 'shared/presenters/tree_node/common'

describe TreeNode::LdapRegion do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:ldap_region) }

  include_examples 'TreeNode::Node#key prefix', 'lr-'
  include_examples 'TreeNode::Node#image', '100/ldap_region.png'

  describe '#title' do
    it 'returns with the name prefixed by Region:' do
      expect(subject.title).to eq("Region: #{object.name}")
    end
  end

  describe '#tooltip' do
    it 'returns with the name prefixed by LDAP Region:' do
      expect(subject.tooltip).to eq("LDAP Region: #{object.name}")
    end
  end
end
