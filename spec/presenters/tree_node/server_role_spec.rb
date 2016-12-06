require 'shared/presenters/tree_node/server_roles'
require 'shared/presenters/tree_node/common'

describe TreeNode::ServerRole do
  include_context 'server roles'
  let(:object) { server_role }
  subject { described_class.new(object, nil, {}) }

  include_examples 'TreeNode::Node#key prefix', 'role-'
  include_examples 'TreeNode::Node#image', '100/role.png'

  describe '#title' do
    it 'returns with title' do
      expect(subject.title).to eq("Role: SmartProxy (stopped)")
    end
  end
end
