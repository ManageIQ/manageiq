describe ContainerLabelTagMapping do
  let(:cat_classification) { FactoryGirl.create(:classification, :read_only => true, :name => 'kubernetes:1') }
  let(:cat_tag) { cat_classification.tag }
  let(:tag1) { cat_classification.add_entry(:name => 'value_1', :description => 'value-1').tag }
  let(:tag2) { cat_classification.add_entry(:name => 'something_else', :description => 'Another tag').tag }
  let(:tag3) { cat_classification.add_entry(:name => 'yet_another', :description => 'Yet another tag').tag }
  let(:empty_tag_under_cat) do
    cat_classification.add_entry(:name => 'my_empty', :description => 'Custom description for empty value').tag
  end
  let(:user_tag1) do
    FactoryGirl.create(:classification_cost_center_with_tags).entries.first.tag
  end
  let(:user_tag2) do
    # What's worse, users can create categories with same name structure - but they won't be read_only:
    cat = FactoryGirl.create(:classification, :name => 'kubernetes::user_could_enter_this')
    cat.add_entry(:name => 'hello', :description => 'Hello').tag
  end
  let(:ems) { FactoryGirl.build(:ext_management_system) }

  def labels(kv)
    kv.map do |name, value|
      {:section => 'labels', :source => 'kubernetes',
       :name => name, :value => value}
    end
  end

  def new_mapper
    ContainerLabelTagMapping.mapper
  end

  # All-in-one
  def map_to_tags(mapper, model_name, labels_kv)
    tag_refs = mapper.map_labels(model_name, labels(labels_kv))
    InventoryRefresh::SaveInventory.save_inventory(ems, [mapper.tags_to_resolve_collection])
    ContainerLabelTagMapping::Mapper.references_to_tags(tag_refs)
  end

  context "with empty mapping" do
    it "does nothing" do
      expect(map_to_tags(new_mapper, 'ContainerNode', 'foo' => 'bar', 'quux' => 'whatever')).to be_empty
    end
  end

  context "with 2 mappings for same label" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag2)
    end

    it "map_labels returns 2 tags" do
      expect(new_mapper.map_labels('ContainerNode', labels('name' => 'value-1')).size).to eq(2)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end
  end

  context "with any-value and specific-value mappings" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag2)
    end

    it "prefers specific-value" do
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end

    it "creates tag for new value" do
      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2)

      mapper1 = ContainerLabelTagMapping.mapper
      tags = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-2')
      expect(tags.size).to eq(1)
      generated_tag = tags[0]
      expect(generated_tag.name).to eq(cat_tag.name + '/value_2')
      expect(generated_tag.classification.description).to eq('value-2')

      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, generated_tag)

      # But nothing changes when called again, the previously created tag is re-used.

      tags2 = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-2')
      expect(tags2).to contain_exactly(generated_tag)

      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, generated_tag)

      # And nothing changes when we re-load the mappings table.

      mapper2 = ContainerLabelTagMapping.mapper

      tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-2')
      expect(tags2).to contain_exactly(generated_tag)

      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, generated_tag)
    end

    it "handles names that differ only by case" do
      # Kubernetes names are case-sensitive
      # (but the optional domain prefix must be lowercase).
      FactoryGirl.create(:container_label_tag_mapping,
                         :label_name => 'Name_Case', :label_value => 'value', :tag => tag2)
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name_case' => 'value')
      tags2 = map_to_tags(new_mapper, 'ContainerNode', 'Name_Case' => 'value', 'naME_caSE' => 'value')
      expect(tags).to be_empty
      expect(tags2).to contain_exactly(tag2)

      # Note: this test doesn't cover creation of the category, eg. you can't have
      # /managed/kubernetes:name vs /managed/kubernetes:naME.
    end

    it "handles values that differ only by case / punctuation" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-case.punct')
      tags2 = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'VaLuE-CASE.punct')
      tags3 = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-case/punct')
      # TODO: They get mapped to the same tag, is this desired?
      # TODO: What do we want the description to be?
      expect(tags2).to eq(tags)
      expect(tags3).to eq(tags)
    end

    it "handles values that differ only past 50th character" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'x' * 50)
      tags2 = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'x' * 50 + 'y')
      tags3 = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'x' * 50 + 'z')
      # TODO: They get mapped to the same tag, is this desired?
      # TODO: What do we want the description to be?
      expect(tags2).to eq(tags)
      expect(tags3).to eq(tags)
    end

    # With multiple providers you'll have multiple refresh workers,
    # each with independently cached mapping table.
    context "2 workers with independent cache" do
      it "handle known value simultaneously" do
        mapper1 = ContainerLabelTagMapping.mapper
        mapper2 = ContainerLabelTagMapping.mapper
        tags1 = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-1')
        tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-1')
        expect(tags1).to contain_exactly(tag1, tag2)
        expect(tags2).to contain_exactly(tag1, tag2)
      end

      it "handle new value encountered simultaneously" do
        mapper1 = ContainerLabelTagMapping.mapper
        mapper2 = ContainerLabelTagMapping.mapper
        tags1 = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-2')
        tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-2')
        expect(tags1.size).to eq(1)
        expect(tags1).to eq(tags2)
      end
    end
  end

  context "with 2 any-value mappings onto same category" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :label_name => 'name1', :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_name => 'name2', :tag => cat_tag)
    end

    it "maps same new value in both into 1 new tag" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name1' => 'value', 'name2' => 'value')
      expect(tags.size).to eq(1)
      expect(Tag.controlled_by_mapping).to contain_exactly(tags[0])
    end
  end

  context "given a label with empty value" do
    it "any-value mapping is ignored" do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to be_empty
    end

    it "honors specific mapping for the empty value" do
      FactoryGirl.create(:container_label_tag_mapping, :label_value => '', :tag => empty_tag_under_cat)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
      # same with both any-value and specific-value mappings
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
    end
  end

  # Interactions between any-type and specific-type rows are somewhat arbitrary.
  # Unclear if there is One Right behavior here; treating them independently
  # seemed the simplest well-defined behavior...

  context "with any-type and specific-type mappings" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "applies both independently" do
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value')).to contain_exactly(tag1, tag2)
    end

    it "skips specific-type when type doesn't match" do
      expect(map_to_tags(new_mapper, 'ContainerProject', 'name' => 'value')).to contain_exactly(tag2)
    end
  end

  context "any-type specific-value vs specific-type any-value" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "resolves them independently" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value')
      expect(tags.size).to eq(2)
      expect(tags).to include(tag2)
    end
  end

  describe ".retag_entity" do
    let(:node) { FactoryGirl.create(:container_node) }

    def ref_to_tag(tag)
      instance_double(InventoryRefresh::InventoryObject, :id => tag.id)
    end

    before do
      # For tag1, tag2 to be controlled by the mapping, though current implementation doesn't care.
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      tag1
      tag2

      user_tag1
      user_tag2
    end

    it "assigns new tags, idempotently" do
      expect(node.tags).to be_empty
      ContainerLabelTagMapping.retag_entity(node, [ref_to_tag(tag1)])
      expect(node.tags).to contain_exactly(tag1)
      ContainerLabelTagMapping.retag_entity(node, [ref_to_tag(tag1)])
      expect(node.tags).to contain_exactly(tag1)
    end

    it "unassigns obsolete mapping-controlled tags" do
      node.tags = [tag1]
      ContainerLabelTagMapping.retag_entity(node, [])
      expect(node.tags).to be_empty
    end

    it "preserves user tags" do
      user_tag = FactoryGirl.create(:tag, :name => '/managed/mycat/mytag')
      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, tag3)
      node.tags = [tag1, user_tag1, user_tag2, tag2]
      expect(node.tags.controlled_by_mapping).to contain_exactly(tag1, tag2)

      ContainerLabelTagMapping.retag_entity(node, [ref_to_tag(tag1), ref_to_tag(tag3)])

      expect(node.tags).to contain_exactly(user_tag1, user_tag2, tag1, tag3)
      expect(node.tags.controlled_by_mapping).to contain_exactly(tag1, tag3)
    end

    # What happens with tags no mapping points to?
    it "considers appropriately named tags as mapping-controlled" do
      cat = FactoryGirl.create(:classification, :read_only => true, :name => 'kubernetes:foo')
      k_tag = cat.add_entry(:name => 'unrelated', :description => 'Unrelated tag').tag
      cat = FactoryGirl.create(:classification, :read_only => true, :name => 'amazon:river')
      a_tag = cat.add_entry(:name => 'jungle', :description => 'Rainforest').tag

      expect(Tag.controlled_by_mapping).not_to include(user_tag1, user_tag2)
      expect(Tag.controlled_by_mapping).to include(k_tag, a_tag)
    end
  end
end
