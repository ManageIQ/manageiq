describe TreeBuilderPolicy do
  context '#tree_init_options' do
    it "is explicitly not lazy" do
      tree = TreeBuilderPolicy.new(:policy_tree, :policy, {}, true)
      options = tree.instance_variable_get(:@options)
      expect(options[:lazy]).to eq(false)
    end
  end
end
