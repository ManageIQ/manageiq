describe ResourceGroup do
  let(:resource_group) do
    FactoryGirl.create(
      :resource_group,
      :type    => "ResourceGroup",
      :name    => "foo",
      :ems_ref => "/subscriptions/xxx/resourceGroups/foo"
    )
  end

  context "properties" do
    it "has the expected resource group" do
      expect(resource_group.type).to eql("ResourceGroup")
    end

    it "has the expected name" do
      expect(resource_group.name).to eql("foo")
    end

    it "has the expected ems_ref" do
      expect(resource_group.ems_ref).to eql("/subscriptions/xxx/resourceGroups/foo")
    end
  end

  context "relationships" do
    it "has many vms" do
      expect(resource_group).to respond_to(:vms)
    end
  end
end
