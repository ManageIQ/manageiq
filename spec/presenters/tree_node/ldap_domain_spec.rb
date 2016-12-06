require 'shared/presenters/tree_node/common'

describe TreeNode::LdapDomain do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:ldap_domain) }

  include_examples 'TreeNode::Node#key prefix', 'ld-'
  include_examples 'TreeNode::Node#image', '100/ldap_domain.png'

  describe '#title' do
    it 'returns with the name prefixed by Domain:' do
      expect(subject.title).to eq("Domain: #{object.name}")
    end
  end

  describe '#tooltip' do
    it 'returns with the name prefixed by LDAP Domain:' do
      expect(subject.tooltip).to eq("LDAP Domain: #{object.name}")
    end
  end
end
