describe ContainerLabelTagMapping do
  let(:cat_classification) { FactoryGirl.create(:classification, :read_only => true) }
  let(:cat_tag) { cat_classification.tag }
  let(:tag1) { cat_classification.add_entry(:name => 'value_1', :description => 'value-1').tag }
  let(:tag2) { cat_classification.add_entry(:name => 'something_else', :description => 'Another tag').tag }
  let(:tag3) { cat_classification.add_entry(:name => 'yet_another', :description => 'Yet another tag').tag }
  let(:empty_tag_under_cat) do
    cat_classification.add_entry(:name => 'my_empty', :description => 'Custom description for empty value').tag
  end
  let(:tag_in_another_cat) do
    cat = FactoryGirl.create(:classification, :read_only => true)
    cat.add_entry(:name => 'unrelated', :description => 'Unrelated tag').tag
  end

  def labels(kv)
    kv.map do |name, value|
      {:section => 'labels', :source => 'kubernetes',
       :name => name, :value => value}
    end
  end

  def map_labels(model_name, labels_kv)
    ContainerLabelTagMapping.map_labels(ContainerLabelTagMapping.cache,
                                        model_name,
                                        labels(labels_kv))
  end

  def to_tags(tag_hashes)
    tag_hashes.map { |h| ContainerLabelTagMapping.find_or_create_tag(h) }
  end

  # All-in-one
  def map_to_tags(model_name, labels_kv)
    to_tags(map_labels(model_name, labels_kv))
  end

  context "with empty mapping" do
    it "does nothing" do
      expect(ContainerLabelTagMapping.cache).to be_empty
      expect(map_labels('ContainerNode',
                        'foo'  => 'bar',
                        'quux' => 'whatever')).to be_empty
    end
  end

  context "with 2 mappings for same label" do
    before(:each) do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag2)
    end

    it "map_labels returns 2 tags" do
      expect(map_labels('ContainerNode', 'name' => 'value-1')).to contain_exactly(
        {:tag_id => tag1.id},
        {:tag_id => tag2.id}
      )
      expect(map_to_tags('ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end
  end

  context "with any-value and specific-value mappings" do
    before(:each) do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag2)
      # Force a tag to exist that we don't map to (for testing .controls_tag?).
      tag_in_another_cat
    end

    it "prefers specific-value" do
      expect(map_to_tags('ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end

    it "creates tag for new value" do
      expect(ContainerLabelTagMapping.controls_tag?(tag1)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag2)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag_in_another_cat)).to be false

      cached1 = ContainerLabelTagMapping.cache
      tags = to_tags(ContainerLabelTagMapping.map_labels(cached1, 'ContainerNode', labels('name' => 'value-2')))
      expect(tags.size).to eq(1)
      expect(tags[0].name).to eq(cat_tag.name + '/value_2')
      expect(tags[0].classification.description).to eq('value-2')

      expect(ContainerLabelTagMapping.controls_tag?(tag1)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag2)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tags[0])).to be true

      # But nothing changes when called again, the previously created tag is re-used.

      tags2 = to_tags(ContainerLabelTagMapping.map_labels(cached1, 'ContainerNode', labels('name' => 'value-2')))
      expect(tags2).to contain_exactly(tags[0])

      expect(ContainerLabelTagMapping.controls_tag?(tag1)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag2)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tags[0])).to be true

      # And nothing changes when we re-load the mappings table.

      cached2 = ContainerLabelTagMapping.cache

      tags2 = to_tags(ContainerLabelTagMapping.map_labels(cached2, 'ContainerNode', labels('name' => 'value-2')))
      expect(tags2).to contain_exactly(tags[0])

      expect(ContainerLabelTagMapping.controls_tag?(tag1)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag2)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tags[0])).to be true
    end

    it "handles names that differ only by case" do
      # Kubernetes names are case-sensitive
      # (but the optional domain prefix must be lowercase).
      FactoryGirl.create(:container_label_tag_mapping,
                         :label_name => 'Name_Case', :label_value => 'value', :tag => tag2)
      tags = map_to_tags('ContainerNode', 'name_case' => 'value')
      tags2 = map_to_tags('ContainerNode', 'Name_Case' => 'value', 'naME_caSE' => 'value')
      expect(tags).to be_empty
      expect(tags2).to contain_exactly(tag2)

      # Note: this test doesn't cover creation of the category, eg. you can't have
      # /managed/kubernetes:name vs /managed/kubernetes:naME.
    end

    it "handles values that differ only by case / punctuation" do
      tags = map_to_tags('ContainerNode', 'name' => 'value-case.punct')
      tags2 = map_to_tags('ContainerNode', 'name' => 'VaLuE-CASE.punct')
      tags3 = map_to_tags('ContainerNode', 'name' => 'value-case/punct')
      # TODO: They get mapped to the same tag, is this desired?
      # TODO: What do we want the description to be?
      expect(tags2).to eq(tags)
      expect(tags3).to eq(tags)
    end

    it "handles values that differ only past 50th character" do
      tags = map_to_tags('ContainerNode', 'name' => 'x' * 50)
      tags2 = map_to_tags('ContainerNode', 'name' => 'x' * 50 + 'y')
      tags3 = map_to_tags('ContainerNode', 'name' => 'x' * 50 + 'z')
      # TODO: They get mapped to the same tag, is this desired?
      # TODO: What do we want the description to be?
      expect(tags2).to eq(tags)
      expect(tags3).to eq(tags)
    end

    # With multiple providers you'll have multiple refresh workers,
    # each with independently cached mapping table.
    context "2 workers with independent cache" do
      it "handle known value simultaneously" do
        cached1 = ContainerLabelTagMapping.cache
        cached2 = ContainerLabelTagMapping.cache
        tags1 = to_tags(ContainerLabelTagMapping.map_labels(cached1, 'ContainerNode', labels('name' => 'value-1')))
        tags2 = to_tags(ContainerLabelTagMapping.map_labels(cached2, 'ContainerNode', labels('name' => 'value-1')))
        expect(tags1).to contain_exactly(tag1, tag2)
        expect(tags2).to contain_exactly(tag1, tag2)
      end

      it "handle new value encountered simultaneously" do
        cached1 = ContainerLabelTagMapping.cache
        cached2 = ContainerLabelTagMapping.cache
        tags1 = to_tags(ContainerLabelTagMapping.map_labels(cached1, 'ContainerNode', labels('name' => 'value-2')))
        tags2 = to_tags(ContainerLabelTagMapping.map_labels(cached2, 'ContainerNode', labels('name' => 'value-2')))
        expect(tags1.size).to eq(1)
        expect(tags1).to eq(tags2)
      end
    end
  end

  context "with 2 any-value mappings onto same category" do
    before(:each) do
      FactoryGirl.create(:container_label_tag_mapping, :label_name => 'name1', :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_name => 'name2', :tag => cat_tag)
    end

    it "maps same new value in both into 1 new tag" do
      tags = map_to_tags('ContainerNode', 'name1' => 'value', 'name2' => 'value')
      expect(tags.size).to eq(1)
      expect(ContainerLabelTagMapping.controls_tag?(tags[0])).to be true
    end
  end

  context "given a label with empty value" do
    it "any-value mapping is ignored" do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      expect(map_to_tags('ContainerNode', 'name' => '')).to be_empty
    end

    it "honors specific mapping for the empty value" do
      FactoryGirl.create(:container_label_tag_mapping, :label_value => '', :tag => empty_tag_under_cat)
      expect(map_to_tags('ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
      # same with both any-value and specific-value mappings
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      expect(map_to_tags('ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
    end
  end

  # Interactions between any-type and specific-type rows are somewhat arbitrary.
  # Unclear if there is One Right behavior here; treating them independently
  # seemed the simplest well-defined behavior...

  context "with any-type and specific-type mappings" do
    before(:each) do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "applies both independently" do
      expect(map_to_tags('ContainerNode', 'name' => 'value')).to contain_exactly(tag1, tag2)
    end

    it "skips specific-type when type doesn't match" do
      expect(map_to_tags('ContainerProject', 'name' => 'value')).to contain_exactly(tag2)
    end
  end

  context "any-type specific-value vs specific-type any-value" do
    before(:each) do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "resolves them independently" do
      tags = map_to_tags('ContainerNode', 'name' => 'value')
      expect(tags.size).to eq(2)
      expect(tags).to include(tag2)
    end
  end

  describe ".retag_entity" do
    let(:node) { FactoryGirl.create(:container_node) }
    before(:each) do
      # For tag1, tag2 etc. to be considered controlled by the mapping
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
    end

    it "assigns new tags, idempotently" do
      expect(node.tags).to be_empty
      ContainerLabelTagMapping.retag_entity(node, [{:tag_id => tag1.id}])
      expect(node.tags).to contain_exactly(tag1)
      ContainerLabelTagMapping.retag_entity(node, [{:tag_id => tag1.id}])
      expect(node.tags).to contain_exactly(tag1)
    end

    it "unassigns obsolete mapping-controlled tags" do
      node.tags = [tag1]
      ContainerLabelTagMapping.retag_entity(node, [])
      expect(node.tags).to be_empty
    end

    it "preserves user tags" do
      user_tag = FactoryGirl.create(:tag, :name => '/managed/mycat/mytag')
      expect(ContainerLabelTagMapping.controls_tag?(user_tag)).to be false
      expect(ContainerLabelTagMapping.controls_tag?(tag1)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag2)).to be true
      expect(ContainerLabelTagMapping.controls_tag?(tag3)).to be true
      node.tags = [tag1, user_tag, tag2]
      ContainerLabelTagMapping.retag_entity(node, [{:tag_id => tag1.id}, {:tag_id => tag3.id}])
      expect(node.tags).to contain_exactly(user_tag, tag1, tag3)
    end
  end
end
