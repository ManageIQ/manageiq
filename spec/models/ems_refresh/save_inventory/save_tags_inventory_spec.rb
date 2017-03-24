context "save_vms_inventory mapping tags" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_amazon, :zone => @zone)
    @vm   = FactoryGirl.create(:vm, :ext_management_system => @ems)

    @tag1 = FactoryGirl.create(:tag, :name => '/managed/amazon:vm:owner')
    @tag2 = FactoryGirl.create(:tag, :name => '/managed/kubernetes:container_node:stuff')
    @tag3 = FactoryGirl.create(:tag, :name => '/managed/kubernetes:foo') # All

    @cat1 = FactoryGirl.create(:category, :description => 'amazon_vm_owner', :tag => @tag1)
    @cat2 = FactoryGirl.create(:category, :description => 'department', :tag => @tag2)
    @cat3 = FactoryGirl.create(:category, :description => 'location', :tag => @tag3)

    @map1 = FactoryGirl.create(
      :container_label_tag_mapping,
      :labeled_resource_type => 'Vm',
      :label_name            => 'owner',
      :tag                   => @tag1
    )

=begin
    @map2 = FactoryGirl.create(
      :container_label_tag_mapping,
      :labeled_resource_type => 'ContainerNode',
      :label_name            => 'owner',
      :tag                   => @tag2
    )

    @map3 = FactoryGirl.create(
      :container_label_tag_mapping,
      :labeled_resource_type => nil,
      :label_name            => 'owner',
      :tag                   => @tag3
    )
=end
  end

  let(:data) do
    {:tags =>
      [
        {
          :category_tag_id   => @cat1.tag_id,
          :entry_name        => 'amazon_vm_owner',
          :entry_description => 'Daniel'
        }
      ]
    }
  end

  it "creates the expected number of taggings" do
    EmsRefresh.save_tags_inventory(@vm, data)
    taggings = Tagging.all
    expect(taggings.size).to eql(1)
  end
end
