require 'shared/presenters/tree_node/common'

describe TreeNode::MiqAeNamespace do
  before { login_as FactoryGirl.create(:user_with_group) }
  subject { described_class.new(object, nil, {}) }

  let(:object) do
    domain = FactoryGirl.create(:miq_ae_domain)
    FactoryGirl.create(:miq_ae_namespace, :parent => domain)
  end

  include_examples 'TreeNode::Node#key prefix', 'aen-'
  include_examples 'TreeNode::Node#image', '100/ae_namespace.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Automate Namespace'

  context 'MiqAeDomain' do
    let(:object) { FactoryGirl.create(:miq_ae_domain, :name => "test1") }

    describe '#title' do
      it 'returns without any suffix' do
        expect(subject.title).to eq('test1')
      end
    end

    context 'disabled' do
      let(:object) { FactoryGirl.create(:miq_ae_domain, :name => "test1", :enabled => false) }

      describe '#title' do
        it 'returns disabled in the suffix' do
          expect(subject.title).to eq('test1 (Disabled)')
        end
      end
    end

    context 'locked' do
      let(:object) { FactoryGirl.create(:miq_ae_system_domain_enabled, :name => "test1") }

      describe '#title' do
        it 'returns locked in the suffix' do
          expect(subject.title).to eq('test1 (Locked)')
        end
      end
    end

    context 'locked & disabled' do
      let(:object) { FactoryGirl.create(:miq_ae_system_domain, :name => "test1") }

      describe '#title' do
        it 'returns both locked and disabled in the suffix' do
          expect(subject.title).to eq('test1 (Locked & Disabled)')
        end
      end
    end
  end
end
