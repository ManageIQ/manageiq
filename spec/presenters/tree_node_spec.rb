describe TreeNode do
  # Force load all the TreeNode:: subclasses
  Dir[Rails.root.join('app', 'presenters', 'tree_node', '*.rb')].each { |f| require f }

  # FIXME: rewrite this to FactoryGirl
  let(:object) do
    # We need a Zone & Server for creating a MiqSchedule
    EvmSpecHelper.create_guid_miq_server_zone if klass == MiqSchedule
    klass.new
  end
  let(:parent_id) { dup }
  let(:options) { Hash.new }
  subject { TreeNode.new(object, parent_id, options) }

  describe '.new' do
    shared_examples 'instance variables' do
      it 'sets instance variables' do
        expect(subject.instance_variable_get(:@object)).to eq(object)
        expect(subject.instance_variable_get(:@parent_id)).to eq(parent_id)
        expect(subject.instance_variable_get(:@options)).to eq(options)
      end
    end

    TreeNode.constants.each do |type|
      # We never instantiate MiqAeNode and Node in our codebase
      next if [:MiqAeNode, :Node].include?(type)

      describe(type) do
        let(:klass) { type.to_s.constantize }

        it 'initializes a new instance' do
          expect(subject).to be_a("TreeNode::#{klass}".constantize)
        end

        include_examples 'instance variables'

        # Skip tests for descendants of Hash
        next if type == :Hash

        type.to_s.constantize.descendants.each do |subtype|
          describe(subtype) do
            let(:klass) { subtype }

            it 'initializes a new instance' do
              expect(subject).to be_a("TreeNode::#{klass.base_class}".constantize)
            end

            include_examples 'instance variables'
          end
        end
      end
    end
  end
end
