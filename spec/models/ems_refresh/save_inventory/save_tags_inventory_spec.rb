context "save_tags_inventory" do
  # @return [Tag] for a category linked to a mapping.
  def mapped_cat(category_name)
    mapping = FactoryGirl.create(:tag_mapping_with_category,
                                 :category_name        => category_name,
                                 :category_description => category_name)
    mapping.tag.classification
  end

  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_amazon, :zone => @zone)

    @vm   = FactoryGirl.create(:vm, :ext_management_system => @ems)
    @node = FactoryGirl.create(:container_node, :ext_management_system => @ems)

    @cat1 = mapped_cat('amazon:vm:owner')
    @cat2 = mapped_cat('kubernetes:container_node:stuff')
    @cat3 = mapped_cat('kubernetes::foo') # All entities
  end

  # This is what ContainerLabelTagMapping.map_labels(cache, 'Type', labels) would
  # return in the refresh parser. Note that we don't explicitly test the mapping
  # creation here, the assumption is that these were the generated mappings.
  #
  let(:tag1_hash) do
    {
      :category_tag_id   => @cat1.tag_id,
      :entry_name        => 'owner',
      :entry_description => 'Daniel'
    }
  end
  let(:tag2_hash) do
    {
      :category_tag_id   => @cat2.tag_id,
      :entry_name        => 'stuff',
      :entry_description => 'Ladas'
    }
  end
  let(:tag3_hash) do
    {
      :category_tag_id   => @cat3.tag_id,
      :entry_name        => 'foo',
      :entry_description => 'Bronagh'
    }
  end

  let(:data) do
    {
      :tags => [
        tag1_hash,
        tag2_hash,
        tag3_hash
      ]
    }
  end
  let(:data2) do
    {
      :tags => [
        tag2_hash
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
