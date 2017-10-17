context "save_tags_inventory" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_amazon, :zone => @zone)

    @vm   = FactoryGirl.create(:vm, :ext_management_system => @ems)
    @node = FactoryGirl.create(:container_node, :ext_management_system => @ems)

    # These might not pass the ContainerLabelTagMapping.controls_tag? criteria, doesn't matter if only adding.
    @tag1 = FactoryGirl.create(:tag, :name => '/managed/amazon:vm:owner/alice')
    @tag2 = FactoryGirl.create(:tag, :name => '/managed/kubernetes:container_node:stuff/jabberwocky')
    @tag3 = FactoryGirl.create(:tag, :name => '/managed/kubernetes::foo/bar') # All
  end

  # This is what ContainerLabelTagMapping::Mapper.map_labels(cache, 'Type', labels) would
  # return in the refresh parser. Note that we don't explicitly test the mapping
  # creation here, the assumption is that these were the generated mappings.
  let(:data) do
    {
      :tags => [
        {:tag_id => @tag1.id},
        {:tag_id => @tag2.id},
        {:tag_id => @tag3.id},
      ]
    }
  end

  # Note that in these tests we're explicitly passing the object, so that's
  # why the object type may not match what you would expect from the tag
  # name type above.

  it "creates the expected number of taggings" do
    EmsRefresh.save_tags_inventory(@vm, data)
    taggings = Tagging.all
    expect(taggings.size).to eql(3)
    expect(@vm.tags.size).to eql(3)
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
