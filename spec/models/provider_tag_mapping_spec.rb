RSpec.describe ProviderTagMapping do
  let(:cat_classification) { FactoryBot.create(:classification, :read_only => true, :name => 'kubernetes:1') }
  let(:cat_tag) { cat_classification.tag }
  let(:tag1) { cat_classification.add_entry(:name => 'value_1', :description => 'value-1').tag }
  let(:tag2) { cat_classification.add_entry(:name => 'something_else', :description => 'Another tag').tag }
  let(:tag3) { cat_classification.add_entry(:name => 'yet_another', :description => 'Yet another tag').tag }
  let(:empty_tag_under_cat) do
    cat_classification.add_entry(:name => 'my_empty', :description => 'Custom description for empty value').tag
  end
  let(:user_tag1) do
    FactoryBot.create(:classification_cost_center_with_tags).entries.first.tag
  end
  let(:user_tag2) do
    # What's worse, users can create categories with same name structure - but they won't be read_only:
    cat = FactoryBot.create(:classification, :name => 'kubernetes::user_could_enter_this')
    cat.add_entry(:name => 'hello', :description => 'Hello').tag
  end

  let(:ems) { FactoryBot.create(:ext_management_system) }

  let(:ems_amazon)       { FactoryBot.create(:ems_amazon) }
  let(:amazon_persister) { ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager.new(ems_amazon, ems_amazon) }

  def label(key_value_label)
    key_value_label.map do |name, value|
      {:section => 'labels', :source => 'kubernetes',
       :name => name, :value => value}
    end
  end

  def labels(label_or_array)
    (label_or_array.kind_of?(Hash) ? [label_or_array] : label_or_array).map do |key_value_label|
      label(key_value_label)
    end.flatten
  end

  def new_mapper
    ProviderTagMapping.mapper(:case_sensitive_labels => amazon_persister.send(:case_sensitive_labels?))
  end

  # All-in-one
  def map_to_tags(mapper, model_name, labels_kv)
    tag_refs = mapper.map_labels(model_name, labels(labels_kv))
    InventoryRefresh::SaveInventory.save_inventory(ems, [mapper.tags_to_resolve_collection])
    ProviderTagMapping::Mapper.references_to_tags(tag_refs)
  end

  context "with empty mapping" do
    it "does nothing" do
      expect(map_to_tags(new_mapper, 'ContainerNode', 'foo' => 'bar', 'quux' => 'whatever')).to be_empty
    end
  end

  context "with 2 mappings for same label" do
    before do
      FactoryBot.create(:provider_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag1)
      FactoryBot.create(:provider_tag_mapping, :only_nodes, :label_value => 'value-1', :tag => tag2)
    end

    it "map_labels returns 2 tags" do
      expect(new_mapper.map_labels('ContainerNode', labels('name' => 'value-1')).size).to eq(2)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end
  end

  context "with any-value and specific-value mappings" do
    before do
      FactoryBot.create(:provider_tag_mapping, :tag => cat_tag)
      FactoryBot.create(:provider_tag_mapping, :label_value => 'value-1', :tag => tag1)
      FactoryBot.create(:provider_tag_mapping, :label_value => 'value-1', :tag => tag2)
    end

    it "prefers specific-value" do
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value-1')).to contain_exactly(tag1, tag2)
    end

    it "creates tag for new value" do
      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2)

      mapper1 = ProviderTagMapping.mapper
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

      mapper2 = ProviderTagMapping.mapper

      tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-2')
      expect(tags2).to contain_exactly(generated_tag)

      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, generated_tag)
    end

    it "handles names that differ only by case" do
      # Kubernetes names are case-sensitive
      # (but the optional domain prefix must be lowercase).
      allow(ems).to receive(:case_insensitive_labels?).and_return(false) # kubernetes
      FactoryBot.create(:provider_tag_mapping, :label_name => 'Name_Case', :label_value => 'value', :tag => tag2)
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
        mapper1 = ProviderTagMapping.mapper
        mapper2 = ProviderTagMapping.mapper
        tags1 = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-1')
        tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-1')
        expect(tags1).to contain_exactly(tag1, tag2)
        expect(tags2).to contain_exactly(tag1, tag2)
      end

      it "handle new value encountered simultaneously" do
        mapper1 = ProviderTagMapping.mapper
        mapper2 = ProviderTagMapping.mapper
        tags1 = map_to_tags(mapper1, 'ContainerNode', 'name' => 'value-2')
        tags2 = map_to_tags(mapper2, 'ContainerNode', 'name' => 'value-2')
        expect(tags1.size).to eq(1)
        expect(tags1).to eq(tags2)
      end
    end
  end

  context "with 2 any-value mappings onto same category" do
    before do
      FactoryBot.create(:provider_tag_mapping, :label_name => 'name1', :tag => cat_tag)
      FactoryBot.create(:provider_tag_mapping, :label_name => 'name2', :tag => cat_tag)
    end

    it "maps same new value in both into 1 new tag" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name1' => 'value', 'name2' => 'value')
      expect(tags.size).to eq(1)
      expect(Tag.controlled_by_mapping).to contain_exactly(tags[0])
    end
  end

  context "given a label with empty value" do
    it "any-value mapping is ignored" do
      FactoryBot.create(:provider_tag_mapping, :tag => cat_tag)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to be_empty
    end

    it "honors specific mapping for the empty value" do
      FactoryBot.create(:provider_tag_mapping, :label_value => '', :tag => empty_tag_under_cat)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
      # same with both any-value and specific-value mappings
      FactoryBot.create(:provider_tag_mapping, :tag => cat_tag)
      expect(map_to_tags(new_mapper, 'ContainerNode', 'name' => '')).to contain_exactly(empty_tag_under_cat)
    end
  end

  context "with Image" do
    let!(:single_value_category) { FactoryBot.create(:classification_environment_with_tags) }
    let!(:multi_value_category)  { FactoryBot.create(:classification_department_with_tags) }

    let!(:vm)        { FactoryBot.create(:vm_amazon, :ems_id => ems_amazon.id, :ems_ref => "some_ems_ref", :uid_ems => "some_ems_ref") }
    let(:mapper)     { new_mapper }

    let(:vm_inventory_object) { amazon_persister.vms.find_or_build("some_ems_ref") }

    let(:taggings_collections) do
      vm_collection       = amazon_persister.inventory_collections[9]
      taggings_collection = amazon_persister.inventory_collections[8]
      tags_collection     = mapper.tags_to_resolve_collection

      [tags_collection, vm_collection, taggings_collection]
    end

    let(:externals_labels) { [] }

    def populate_taggings_collections_with(inventory_objects)
      inventory_objects.each do |inventory_object|
        amazon_persister.vm_and_template_taggings.build(:taggable => vm_inventory_object, :tag => inventory_object)
      end
    end

    subject do
      tags_inventory_objects = mapper.map_labels("Image", externals_labels)
      populate_taggings_collections_with(tags_inventory_objects)
      InventoryRefresh::SaveInventory.save_inventory(ems_amazon, taggings_collections)
    end

    describe "#cached_filter_single_value_category_tag_ids" do
      it "uses cache properly for single value categories" do
        where_params = {:tag_id => [single_value_category.tag_id], :single_value => true}
        expect(Classification).to receive(:where).with(where_params).exactly(1).times.and_call_original

        mapper = new_mapper
        tag_ids = mapper.cached_filter_single_value_category_tag_ids([single_value_category.tag_id])
        mapper.cached_filter_single_value_category_tag_ids([single_value_category.tag_id])
        expect(tag_ids).to eq([single_value_category.tag_id])
      end

      it "uses cache properly for multi and single value categories" do
        input_tag_ids = [single_value_category.tag_id, multi_value_category.tag_id]
        where_params = {:tag_id => input_tag_ids, :single_value => true}
        expect(Classification).to receive(:where).with(where_params).exactly(1).times.and_call_original

        mapper = new_mapper
        tag_ids = mapper.cached_filter_single_value_category_tag_ids(input_tag_ids)
        mapper.cached_filter_single_value_category_tag_ids([single_value_category.tag_id])
        mapper.cached_filter_single_value_category_tag_ids([multi_value_category.tag_id])
        mapper.cached_filter_single_value_category_tag_ids(input_tag_ids)

        expect(tag_ids).to eq([single_value_category.tag_id])
      end
    end

    %w[nAme Name].each do |label_name|
      before do
        allow(amazon_persister).to receive(:case_sensitive_labels?).and_return(false)
      end

      context "with mapping to single-value, existing category and label name: #{label_name}" do
        before do
          FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Name", :tag => single_value_category.tag)
        end

        let(:externals_labels) do # provider label
          [{:name => label_name, :value => 'Accounting'}]
        end

        it "replaces an existing tag on the resource with the value of the external label" do
          expect(vm.tags).to be_empty

          existing_tag_on_vm = Tag.lookup_by_classification_name('environment/quarantine')
          vm.tag_add(existing_tag_on_vm.name, :ns => '')

          expect(vm.reload.tags).to eq([existing_tag_on_vm])

          subject

          expected_tags = [Tag.lookup_by_classification_name('environment/accounting')]
          expect(vm.reload.tags).to eq(expected_tags)
        end

        it "adds a tag to the resource with the value of the external label" do
          expect(vm.tags).to be_empty

          subject

          expected_tags = [Tag.lookup_by_classification_name('environment/accounting')]
          expect(vm.reload.tags).to eq(expected_tags)
        end

        it "adds a tag from external label to the resource and pre-existing tag from multi value category" do
          expect(vm.tags).to be_empty

          existing_tag_on_vm = Tag.lookup_by_classification_name('department/hr')
          vm.tag_add(existing_tag_on_vm.name, :ns => '')

          expect(vm.reload.tags).to eq([existing_tag_on_vm])

          subject

          expected_tags = [Tag.lookup_by_classification_name('environment/accounting'), existing_tag_on_vm]
          expect(vm.reload.tags).to match_array(expected_tags)
        end

        context "with multiple mappings" do
          let!(:single_value_category_2) { FactoryBot.create(:classification_location_with_tags) }

          let(:externals_labels) do # provider label
            [{:name => label_name, :value => 'Accounting'},
             {:name => 'Locality', :value => 'Brno'}]
          end

          before do
            FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Locality", :tag => single_value_category_2.tag)
          end

          context "when mappings are targeted to different categories" do
            it "adds tags to resource" do
              expect(vm.tags).to be_empty

              subject

              expected_tags = %w[location/brno environment/accounting].map { |x| Tag.lookup_by_classification_name(x) }
              expect(vm.reload.tags).to match_array(expected_tags)
            end
          end

          context "when mappings are targeted to same categories" do
            let(:externals_labels) do # provider label
              [{:name => label_name, :value => 'Windows'},
               {:name => 'Location', :value => 'Production'},
               {:name => 'Cost Center', :value => '007'}]
            end

            before do
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Location", :tag => single_value_category.tag)
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Cost Center", :tag => single_value_category.tag)
            end

            it "only applies one of the label values" do
              expect(vm.tags).to be_empty

              subject
              expect(vm.reload.tags.count).to eq(1)

              # Only first tag is assigned to Vm and this tag is selected according to
              # alphanumeric order of labels's names
              expect(vm.reload.tags.first.name).to eq("/managed/environment/007")
            end
          end
        end
      end

      context "with mapping with multi-value category and with label name #{label_name}" do
        let!(:multi_value_category_2) { FactoryBot.create(:classification_cost_center_with_tags) }

        let(:externals_labels) do # provider label
          [{:name => label_name, :value => 'Accounting'}]
        end

        before do
          FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Name", :tag => multi_value_category.tag)
        end

        it "adds a tag to the resource with the value of the external label" do
          expect(vm.tags).to be_empty

          subject

          expected_tags = [Tag.lookup_by_classification_name('department/accounting')]
          expect(vm.reload.tags).to eq(expected_tags)
        end

        it "reassigns to the tag specified in the mapping with same category as a pre-existing tag" do
          expect(vm.tags).to be_empty

          existing_tag_on_vm = Tag.lookup_by_classification_name('department/hr')
          vm.tag_add(existing_tag_on_vm.name, :ns => '')
          expect(vm.reload.tags).to eq([existing_tag_on_vm])

          subject

          expect(vm.reload.tags).to match_array([Tag.lookup_by_classification_name('department/accounting')])
        end

        it "adds a tag with the category from mapping, when there is an existing tag on the resource from a different category then that of the mapping" do
          expect(vm.tags).to be_empty

          existing_tag_on_vm = Tag.lookup_by_classification_name('cc/001')
          vm.tag_add(existing_tag_on_vm.name, :ns => '')

          expect(vm.reload.tags).to eq([existing_tag_on_vm])

          subject

          expected_tags = [existing_tag_on_vm, Tag.lookup_by_classification_name('department/accounting')]
          expect(vm.reload.tags).to match_array(expected_tags)
        end

        it "doesn't add new tag during mapping if resource is already tagged with the same tag" do
          expect(vm.tags).to be_empty

          existing_tag_on_vm = Tag.lookup_by_classification_name('department/accounting')
          vm.tag_add(existing_tag_on_vm.name, :ns => '')

          subject

          expect(vm.reload.tags).to match_array([existing_tag_on_vm])
        end

        context "with multiple mappings" do
          let(:externals_labels) do # provider labels
            [{:name => label_name, :value => 'Accounting'},
             {:name => 'Finance Center', :value => '007'}]
          end

          context "when mappings are targeted to different categories" do
            before do
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Name", :tag => multi_value_category.tag)
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Finance Center", :tag => multi_value_category_2.tag)
            end

            it "adds tags to resource" do
              expect(vm.tags).to be_empty

              subject

              expected_tags = %w[cc/007 department/accounting].map { |x| Tag.lookup_by_classification_name(x) }
              expect(vm.reload.tags).to match_array(expected_tags)
            end
          end

          context "when mappings are targeted to same categories" do
            let(:externals_labels) do # provider labels
              [{:name => label_name, :value => 'Accounting'},
               {:name => 'Finance Center', :value => '007'}]
            end

            before do
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Name", :tag => multi_value_category.tag)
              FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => "Finance Center", :tag => multi_value_category.tag)
            end

            it "applies all the label values" do
              expect(vm.tags).to be_empty

              subject

              expected_tags = %w[department/007 department/accounting].map { |x| Tag.lookup_by_classification_name(x) }
              expect(vm.reload.tags).to match_array(expected_tags)
            end
          end
        end
      end
    end
  end

  context "with all entities resource type" do
    let(:other_cat_classification) { FactoryBot.create(:classification, :read_only => true, :name => 'environment') }
    let(:other_cat_tag)            { other_cat_classification.tag }

    before do
      FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => 'name', :tag => cat_tag)
      FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => 'DEV', :tag => cat_tag)
      FactoryBot.create(:provider_tag_mapping, :all_entities, :label_name => 'DEV', :tag => other_cat_tag)
    end

    let(:existing_label) { {"name" => "value_1"} }

    it "creates tag from mapping" do
      map_to_tags(new_mapper, "_all_entities_", existing_label)

      expect(Classification.where(:description => "value_1").first.parent).to eq(cat_tag.classification)
      expect(Classification.where(:description => "value_1").first.parent.tag).to eq(cat_tag)
    end

    let(:existing_label_dev_win) { {"DEV" => "WIN"} }
    let(:existing_label_dev_linux) { {"DEV" => "LINUX"} }

    it "creates tags from mappings with same label name" do
      map_to_tags(new_mapper, "_all_entities_", [existing_label_dev_win, existing_label_dev_linux])
      expect(Tag.find_by(:name => "#{cat_tag.name}/win")).not_to be_nil
      expect(Tag.find_by(:name => "#{other_cat_tag.name}/win")).not_to be_nil
    end
  end

  # Interactions   between any-type and specific-type rows are somewhat arbitrary.
  # Unclear if there is One Right behavior here; treating them independently
  # seemed the simplest well-defined behavior...

  context "with any-type and specific-type mappings" do
    before do
      FactoryBot.create(:provider_tag_mapping, :only_nodes, :label_value => 'value', :tag => tag1)
      FactoryBot.create(:provider_tag_mapping, :label_value => 'value', :tag => tag2)
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
      FactoryBot.create(:provider_tag_mapping, :only_nodes, :tag => cat_tag)
      FactoryBot.create(:provider_tag_mapping, :label_value => 'value', :tag => tag2)
    end

    it "resolves them independently" do
      tags = map_to_tags(new_mapper, 'ContainerNode', 'name' => 'value')
      expect(tags.size).to eq(2)
      expect(tags).to include(tag2)
    end
  end

  describe ".retag_entity" do
    let(:node) { FactoryBot.create(:container_node) }

    def ref_to_tag(tag)
      instance_double(InventoryRefresh::InventoryObject, :id => tag.id)
    end

    before do
      # For tag1, tag2 to be controlled by the mapping, though current implementation doesn't care.
      FactoryBot.create(:provider_tag_mapping, :tag => cat_tag)
      tag1
      tag2
      tag3

      user_tag1
      user_tag2
    end

    it "assigns new tags, idempotently" do
      expect(node.tags).to be_empty
      ProviderTagMapping.retag_entity(node, [ref_to_tag(tag1)])
      expect(node.tags).to contain_exactly(tag1)
      ProviderTagMapping.retag_entity(node, [ref_to_tag(tag1)])
      expect(node.tags).to contain_exactly(tag1)
    end

    it "unassigns obsolete mapping-controlled tags" do
      node.tags = [tag1]
      ProviderTagMapping.retag_entity(node, [])
      expect(node.tags).to be_empty
    end

    it "preserves user tags" do
      user_tag = FactoryBot.create(:tag, :name => '/managed/mycat/mytag')
      expect(Tag.controlled_by_mapping).to contain_exactly(tag1, tag2, tag3)
      node.tags = [tag1, user_tag1, user_tag2, tag2]
      expect(node.tags.controlled_by_mapping).to contain_exactly(tag1, tag2)

      ProviderTagMapping.retag_entity(node, [ref_to_tag(tag1), ref_to_tag(tag3)])

      expect(node.tags).to contain_exactly(user_tag1, user_tag2, tag1, tag3)
      expect(node.tags.controlled_by_mapping).to contain_exactly(tag1, tag3)
    end

    # What happens with tags no mapping points to?
    it "does not consider appropriately named tags as mapping-controlled unless they are included in a mapping" do
      cat = FactoryBot.create(:classification, :read_only => true, :name => 'kubernetes:foo')
      k_tag = cat.add_entry(:name => 'unrelated', :description => 'Unrelated tag').tag
      cat = FactoryBot.create(:classification, :read_only => true, :name => 'amazon:river')
      a_tag = cat.add_entry(:name => 'jungle', :description => 'Rainforest').tag

      expect(Tag.controlled_by_mapping).not_to include(user_tag1, user_tag2)
      expect(Tag.controlled_by_mapping).not_to include(k_tag, a_tag)
    end
  end
end
