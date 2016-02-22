describe TreeBuilder do
  context "initialize" do
    it "initializes a tree" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      expect(tree).to be_a_kind_of(TreeBuilder)
      expect(tree.name).to eq(:cb_rates_tree)
    end

    it "sets sandbox hash that can be accessed by other methods in the class" do
      sb = {}
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", sb)
      expect(tree).to be_a_kind_of(TreeBuilder)
      expect(tree.name).to eq(:cb_rates_tree)
      sb.key?(:trees)
      sb[:trees].key?(:cb_rates_tree)
    end
  end

  context "title_and_tip" do
    it "sets title and tooltip for the passed in root node" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      title, tooltip, icon = tree.root_options
      expect(title).to eq("Rates")
      expect(tooltip).to eq("Rates")
      expect(icon).to be_nil
    end
  end

  context "build_tree" do
    it "builds tree object and sets all settings and add nodes to tree object" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      nodes = [{:key      => "root",
                :children => [],
                :expand   => true,
                :title    => "Rates",
                :tooltip  => "Rates",
                :icon     => ActionController::Base.helpers.image_path('100/folder.png')
              }]
      tree.locals_for_render.key?(:json_tree)
      expect(tree.locals_for_render[:json_tree]).to eq(nodes.to_json)
    end
  end

  context "#locals_for_render" do
    it "returns the active node x_node from the TreeState as select_node" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})

      active_node = 'foobar'
      allow_any_instance_of(TreeState).to receive(:x_node).and_return(active_node)

      expect(tree.locals_for_render[:select_node]).to eq(active_node)
    end
  end

  context "#reload!" do
    it "replaces @tree_nodes" do
      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      tree.instance_eval { @tree_nodes = "{}" }
      tree.reload!
      expect(tree.tree_nodes).not_to eq("{}")
    end
  end

  context "#root_options" do
    let(:tree) do
      Class.new(TreeBuilderChargebackRates) do
        def root_options
          ["Foo", "Bar", nil]
        end
      end.new("cb_rates_tree", "cb_rates", {})
    end

    it "descendants can set their own root_options" do
      expect(tree.tree_nodes).to match(/"title":\s*"Foo"/)
    end
  end

  context '#x_get_child_nodes' do
    it 'returns for Hash models' do
      builder = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      nodes = builder.x_get_child_nodes('tf_xx-10')
      expect(nodes).to be_empty
    end
  end

  context '#node_by_tree_id' do
    it 'returns a correct Hash for Hash models' do
      builder = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", {})
      node = builder.node_by_tree_id('tf_xx-10')
      expect(node).to be_a_kind_of(Hash)
      expect(node[:id]).to eq("10")
      expect(node[:type]).to eq("xx")
      expect(node[:full_id]).to eq("tf_xx-10")
    end
  end

  # This is testing a private method, but it's relied upon by a lot of
  # subclass methods, so it doesn't seem unreasonable to specify its
  # behavior directly.
  context '#count_only_or_objects' do
    let(:builder) do
      Class.new(TreeBuilder) do
        public :count_only_or_objects
      end.new(:test_tree, :test, {}, false)
    end

    it 'counts things in a Relation' do
      a = FactoryGirl.create(:user_with_email)
      FactoryGirl.create(:user_with_email)

      expect(builder.count_only_or_objects(true, User.none, nil)).to eq(0)
      expect(builder.count_only_or_objects(true, User.where(:id => a.id), nil)).to eq(1)
      expect(builder.count_only_or_objects(true, User.all, nil)).to eq(2)
      expect(builder.count_only_or_objects(true, User.select('id, name'), nil)).to eq(2)
    end

    it 'counts things in an Array' do
      expect(builder.count_only_or_objects(true, [], nil)).to eq(0)
      expect(builder.count_only_or_objects(true, [:x], nil)).to eq(1)
      expect(builder.count_only_or_objects(true, [:x, :y, :z, :z, :y], nil)).to eq(5)
    end

    it 'returns a collection when not counting' do
      a = FactoryGirl.create(:user_with_email)
      b = FactoryGirl.create(:user_with_email)

      expect(builder.count_only_or_objects(false, User.none, nil)).to eq([])
      expect(builder.count_only_or_objects(false, User.where(:id => a.id), nil)).to eq([a])
      expect(builder.count_only_or_objects(false, User.all, nil).sort).to eq([a, b].sort)
      expect(builder.count_only_or_objects(false, User.select('id', 'name'), nil).sort).to eq([a, b].sort)

      expect(builder.count_only_or_objects(false, [], nil)).to eq([])
      expect(builder.count_only_or_objects(false, [:x], nil)).to eq([:x])
      expect(builder.count_only_or_objects(false, [:x, :y, :z, :z, :y], nil)).to eq([:x, :y, :z, :z, :y])
    end

    it 'sorts the collection' do
      expect(builder.count_only_or_objects(false, %w(), 'to_s')).to eq(%w())
      expect(builder.count_only_or_objects(false, %w(x), 'to_s')).to eq(%w(x))
      expect(builder.count_only_or_objects(false, %w(c a b), 'to_s')).to eq(%w(a b c))

      expect(
        builder.count_only_or_objects(false, [['c', 1], ['a', 0], ['b', 1], ['d', 0]], %w(second first))
      ).to eq([['a', 0], ['d', 0], ['b', 1], ['c', 1]])

      expect(builder.count_only_or_objects(false, 1..5, ->(i) { [i % 2, i] })).to eq([2, 4, 1, 3, 5])
    end
  end

  context "#open_node" do
    it "adds a node if not present" do
      sb = {}
      node = 'tf_xx-10'

      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", sb)
      tree.send(:open_node, node)

      expect(sb[:trees][:cb_rates_tree][:open_nodes]).to include(node)
    end

    it "doesn't add already present nodes" do
      sb = {}
      node = 'tf_xx-10'

      tree = TreeBuilderChargebackRates.new("cb_rates_tree", "cb_rates", sb)
      tree.send(:open_node, node)
      tree.send(:open_node, node)

      expect(sb[:trees][:cb_rates_tree][:open_nodes].length).to eq(1)
    end
  end
end
