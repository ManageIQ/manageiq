require 'inventory_refresh/inventory_object'

context "save_tags_inventory" do
  # @return [Tag] a tag in a category linked to a mapping.
  def mapped_tag(category_name, tag_name)
    mapping = FactoryBot.create(:tag_mapping_with_category,
                                 :category_name        => category_name,
                                 :category_description => category_name)
    category = mapping.tag.classification
    entry = category.add_entry(:name => tag_name, :description => tag_name)
    entry.tag
  end

  before do
    @zone = FactoryBot.create(:zone)
    @ems  = FactoryBot.create(:ems_amazon, :zone => @zone)

    @vm   = FactoryBot.create(:vm, :ext_management_system => @ems)
    @node = FactoryBot.create(:container_node, :ext_management_system => @ems)

    @tag1 = mapped_tag('amazon:vm:owner', 'alice')
    @tag2 = mapped_tag('kubernetes:container_node:stuff', 'jabberwocky')
    @tag3 = mapped_tag('kubernetes::foo', 'bar') # All entities
  end

  # Simulate what ProviderTagMapping::Mapper.map_labels(...) would return, after resolving to tag ids.
  # Note that we don't explicitly test the mapping
  # creation here, the assumption is that these were the generated mappings.
  let(:data) do
    {
      :tags => [
        instance_double(InventoryRefresh::InventoryObject, :id => @tag1.id),
        instance_double(InventoryRefresh::InventoryObject, :id => @tag2.id),
        instance_double(InventoryRefresh::InventoryObject, :id => @tag3.id),
      ]
    }
  end
  let(:data2) do
    {
      :tags => [
        instance_double(InventoryRefresh::InventoryObject, :id => @tag2.id),
      ]
    }
  end
  let(:data_empty) do
    {
      :tags => []
    }
  end
  let(:data_empty_array) do
    []
  end

  # Note that in these tests we're explicitly passing the object, so that's
  # why the object type may not match what you would expect from the tag
  # name type above.

  it "creates/deletes the expected number of taggings" do
    EmsRefresh.save_tags_inventory(@vm, data)
    expect(Tagging.count).to eql(3)
    expect(@vm.reload.tags.size).to eql(3)

    EmsRefresh.save_tags_inventory(@vm, data_empty)
    expect(Tagging.count).to eql(0)
    expect(@vm.reload.tags.size).to eql(0)

    EmsRefresh.save_tags_inventory(@vm, data2)
    expect(Tagging.count).to eql(1)
    expect(@vm.reload.tags.size).to eql(1)

    EmsRefresh.save_tags_inventory(@vm, data_empty_array)
    expect(Tagging.count).to eql(0)
    expect(@vm.reload.tags.size).to eql(0)
  end

  it "creates the expected taggings for a VM" do
    EmsRefresh.save_tags_inventory(@vm, data)
    taggings = Tagging.all
    expect(taggings.all? { |e| e.taggable_id == @vm.id }).to be true
    expect(taggings.map(&:taggable_type).all? { |e| e == 'VmOrTemplate' }).to be true
    expect(@vm.tags.map(&:id).sort).to eql(taggings.map(&:tag_id).sort)
  end

  it "creates the expected taggings for a container node" do
    EmsRefresh.save_tags_inventory(@node, data)
    taggings = Tagging.all
    expect(taggings.all? { |e| e.taggable_id == @node.id }).to be true
    expect(taggings.map(&:taggable_type).all? { |e| e == 'ContainerNode' }).to be true
    expect(@node.tags.map(&:id).sort).to eql(taggings.map(&:tag_id).sort)
  end
end
