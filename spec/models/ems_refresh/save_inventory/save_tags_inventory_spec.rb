context "save_tags_inventory" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_amazon, :zone => @zone)

    @vm   = FactoryGirl.create(:vm, :ext_management_system => @ems)
    @node = FactoryGirl.create(:container_node, :ext_management_system => @ems)

    @tag1 = FactoryGirl.create(:tag, :name => '/managed/amazon:vm:owner')
    @tag2 = FactoryGirl.create(:tag, :name => '/managed/kubernetes:container_node:stuff')
    @tag3 = FactoryGirl.create(:tag, :name => '/managed/kubernetes:foo') # All

    @cat1 = FactoryGirl.create(:category, :description => 'amazon_vm_owner', :tag => @tag1)
    @cat2 = FactoryGirl.create(:category, :description => 'department', :tag => @tag2)
    @cat3 = FactoryGirl.create(:category, :description => 'location', :tag => @tag3)
  end

  # This is what ContainerLabelTagMapping.map_labels(cache, 'Type', labels) would
  # return in the refresh parser. Note that we don't explicitly test the mapping
  # creation here, the assumption is that these were the generated mappings.
  #
  let(:data) do
    {
      :tags => [
        {
          :category_tag_id   => @cat1.tag_id,
          :entry_name        => 'owner',
          :entry_description => 'Daniel'
        },
        {
          :category_tag_id   => @cat2.tag_id,
          :entry_name        => 'stuff',
          :entry_description => 'Ladas'
        },
        {
          :category_tag_id   => @cat3.tag_id,
          :entry_name        => 'foo',
          :entry_description => 'Bronagh'
        }
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
