describe ContainerLabelTagMapping do
  let(:node) { FactoryGirl.create(:container_node, :name => 'node') }

  def label(node, name, value)
    FactoryGirl.create(:kubernetes_label, :resource => node, :name => name, :value => value)
  end

  let(:tag1) { FactoryGirl.create(:tag, :name => '/ns1/category1/tag1') }
  let(:tag2) { FactoryGirl.create(:tag, :name => '/ns2/category2/tag2') }
  let(:cat_classification) { FactoryGirl.create(:classification) }
  let(:cat_tag) { cat_classification.tag }
  let(:tag_under_cat) { cat_classification.add_entry(:name => 'value_1', :description => 'value-1').tag }

  context "with empty mapping" do
    it "does nothing" do
      expect(ContainerLabelTagMapping.all_tags_for_entity(node)).to be_empty
      expect(ContainerLabelTagMapping.all_mapped_tags).to be_empty
    end
  end

  context "with 2 mappings for same label" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :node, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :node, :label_value => 'value-1', :tag => tag2)
    end

    it "returns 2 tags" do
      label(node, 'name', 'value-1')
      expect(ContainerLabelTagMapping.all_tags_for_entity(node)).to contain_exactly(tag1, tag2)
    end
  end

  context "with any-value and specific-value mappings" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value-1', :tag => tag_under_cat)
      # Force a tag to exist that we don't map to.
      tag2
    end

    it "prefers specific-value" do
      label(node, 'name', 'value-1')
      expect(ContainerLabelTagMapping.all_tags_for_entity(node)).to contain_exactly(tag1, tag_under_cat)
    end

    it "creates tag for new value" do
      expect(ContainerLabelTagMapping.all_mapped_tags).to contain_exactly(tag1, tag_under_cat)

      label(node, 'name', 'value-2')
      tags = ContainerLabelTagMapping.all_tags_for_entity(node)
      expect(tags.size).to eq(1)
      expect(tags[0].name).to eq(cat_tag.name + '/value_2')
      expect(tags[0].classification.description).to eq('value-2')

      expect(ContainerLabelTagMapping.all_mapped_tags).to contain_exactly(tag1, tag_under_cat, tags[0])

      # But nothing changes when called again, the previously created tag is re-used.

      expect(ContainerLabelTagMapping.all_tags_for_entity(node)).to contain_exactly(tags[0])

      expect(ContainerLabelTagMapping.all_mapped_tags).to contain_exactly(tag1, tag_under_cat, tags[0])
    end
  end

  # Interactions between any-type and specific-type rows are somewhat arbitrary.
  # Unclear if there is One Right behavior here; treating them independently
  # seemed the simplest well-defined behavior...

  context "with any-type and specific-type mappings" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :node, :label_value => 'value', :tag => tag1)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "applies both independently" do
      label(node, 'name', 'value')
      expect(ContainerLabelTagMapping.all_tags_for_entity(node)).to contain_exactly(tag1, tag2)
    end
  end

  context "any-type specific-value vs specific-type any-value" do
    before do
      FactoryGirl.create(:container_label_tag_mapping, :node, :tag => cat_tag)
      FactoryGirl.create(:container_label_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "resolves them independently" do
      label(node, 'name', 'value')
      tags = ContainerLabelTagMapping.all_tags_for_entity(node)
      expect(tags.size).to eq(2)
      expect(tags).to include(tag2)
    end
  end
end
