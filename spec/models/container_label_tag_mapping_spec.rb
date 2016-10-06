describe ContainerLabelTagMapping do
  let(:node)  { FactoryGirl.create(:container_node, :name => 'node') }
  let(:node2) { FactoryGirl.create(:container_node, :name => 'node2') }
  let(:node3) { FactoryGirl.create(:container_node, :name => 'node3') }
  let(:project) { FactoryGirl.create(:container_project, :name => 'project') }

  def label(node, name, value)
    FactoryGirl.create(:kubernetes_label, :resource => node, :name => name, :value => value)
  end

  let(:tag1) { FactoryGirl.create(:tag, :name => '/ns1/category1/tag1') }
  let(:tag2) { FactoryGirl.create(:tag, :name => '/ns2/category2/tag2') }
  let(:cat_tag_without_classification) { FactoryGirl.create(:tag, :name => '/ns3/category3') }

  let(:cat_classification) { FactoryGirl.create(:classification) }
  let(:cat_tag) { cat_classification.tag }
  let(:tag_under_cat) { cat_classification.add_entry(:name => 'value_1', :description => 'value-1').tag }
  let(:empty_tag_under_cat) do
    cat_classification.add_entry(:name => 'my_empty', :description => 'Custom description for empty value').tag
  end

  # Each test here may populate the table differently.
  after :each do
    ContainerLabelTagMapping.drop_cache
  end
  # If the mapping was called from *elsewhere* there might already be a stale cache.
  # TODO: This assumes all other tests only use an empty mapping.
  before :all do
    ContainerLabelTagMapping.drop_cache
  end

  context "with empty mapping" do
    it "does nothing" do
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to be_empty
      expect(ContainerLabelTagMapping.mappable_tags).to be_empty
    end
  end

  context "with 2 mappings for same label" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag2)
    end

    it "tags_for_entity returns 2 tags" do
      label(node, 'name', 'value-1')
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(tag1, tag2)
    end

    it "tags_for_label returns same tags" do
      label_obj = OpenStruct.new(:resource_type => 'ContainerNode',
                                 :name          => 'name',
                                 :value         => 'value-1')
      expect(ContainerLabelTagMapping.tags_for_label(label_obj)).to contain_exactly(tag1, tag2)
    end
  end

  context "with any-value and specific-value mappings" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag_under_cat)
      # Force a tag to exist that we don't map to (for testing .mappable_tags).
      tag2
    end

    it "prefers specific-value" do
      label(node, 'name', 'value-1')
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(tag1, tag_under_cat)
    end

    it "creates tag for new value" do
      expect(ContainerLabelTagMapping.mappable_tags).to contain_exactly(tag1, tag_under_cat)

      label(node, 'name', 'value-2')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      expect(tags.size).to eq(1)
      expect(tags[0].name).to eq(cat_tag.name + '/value_2')
      expect(tags[0].classification.description).to eq('value-2')

      expect(ContainerLabelTagMapping.mappable_tags).to contain_exactly(tag1, tag_under_cat, tags[0])

      # But nothing changes when called again, the previously created tag is re-used.

      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(tags[0])

      expect(ContainerLabelTagMapping.mappable_tags).to contain_exactly(tag1, tag_under_cat, tags[0])
    end

    it "handles names that differ only by case" do
      # Kubernetes names are case-sensitive
      # (but the optional domain prefix must be lowercase).
      FactoryGirl.create(:container_label_tag_mapping, :label_name => 'Name_Case', :label_value => 'value', :tag => tag2)
      label(node, 'name_case', 'value')
      label(node2, 'Name_Case', 'value')
      label(node2, 'naME_caSE', 'value')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      tags2 = ContainerLabelTagMapping.tags_for_entity(node2)
      expect(tags).to be_empty
      expect(tags2).to contain_exactly(tag2)

      # Note: this test doesn't cover creation of the category, eg. you can't have
      # /managed/kubernetes:name vs /managed/kubernetes:naME.
    end

    pending "handles values that differ only by case / punctuation" do
      label(node, 'name', 'value-case.punct')
      label(node2, 'name', 'VaLuE-CASE.punct')
      label(node3, 'name', 'value-case/punct')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      tags2 = ContainerLabelTagMapping.tags_for_entity(node2)
      tags3 = ContainerLabelTagMapping.tags_for_entity(node3)
      # TODO: do we want them to get same tag or 2 tags?
      # What do we want the description to be?
    end

    pending "handles values that differ only past 50th character" do
      label(node, 'name', 'x' * 50)
      label(node2, 'name', 'x' * 50 + 'y')
      label(node3, 'name', 'x' * 50 + 'z')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      tags2 = ContainerLabelTagMapping.tags_for_entity(node2)
      tags3 = ContainerLabelTagMapping.tags_for_entity(node3)
    end
  end

  context "given an empty label value" do
    before do
      label(node, 'name', '')
    end

    it "any-value mapping generates a tag" do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      expect(tags.size).to eq(1)
      expect(tags[0].classification.description).to eq('<empty value>')
    end

    it "honors specific mapping for the empty value" do
      FactoryGirl.create(:container_label_tag_mapping, :label_value => '', :tag => empty_tag_under_cat)
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(empty_tag_under_cat)
      # same with both any-value and specific-value mappings
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(empty_tag_under_cat)
    end
  end

  context "with any-value mapping whose tag has no classification" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag_without_classification)
    end

    it "creates specific-value tag and the 2 needed classifications" do
      label(node, 'name', 'value-3')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      expect(tags.size).to eq(1)
      expect(tags[0].category.description).to eq("Kubernetes label 'name'")
      expect(tags[0].classification.description).to eq('value-3')
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
      label(node, 'name', 'value')
      expect(ContainerLabelTagMapping.tags_for_entity(node)).to contain_exactly(tag1, tag2)
    end

    it "skips specific-type when type doesn't match" do
      label(project, 'name', 'value')
      expect(ContainerLabelTagMapping.tags_for_entity(project)).to contain_exactly(tag2)
    end
  end

  context "any-type specific-value vs specific-type any-value" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :only_nodes, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "resolves them independently" do
      label(node, 'name', 'value')
      tags = ContainerLabelTagMapping.tags_for_entity(node)
      expect(tags.size).to eq(2)
      expect(tags).to include(tag2)
    end
  end
end
