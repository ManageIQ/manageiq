
describe ActsAsTaggable do
  before(:each) do
    @host1 = FactoryGirl.create(:host, :name => "HOST1")
    @host1.tag_with("red blue yellow", :ns => "/test", :cat => "tags")
    @host2 = FactoryGirl.create(:host, :name => "HOST2")
    @host3 = FactoryGirl.create(:host, :name => "HOST3")

    @vm1   = FactoryGirl.create(:vm_vmware, :name => "VM1")
    @vm2   = FactoryGirl.create(:vm_vmware, :name => "VM2")
    @vm3   = FactoryGirl.create(:vm_vmware, :name => "VM3")
    @vm4   = FactoryGirl.create(:vm_vmware, :name => "VM4")

    @vm1.tag_with("red blue yellow", :ns => "/test", :cat => "tags")
    @vm3.tag_with("Red Blue Yellow", :ns => "/Test", :cat => "MixedCase")
    @vm4.tag_with("nyc chi la", :cat => "someuser")
    @vm4.tag_add("bos phi blt")
  end

  context ".find_tagged_with" do
    it ":any" do
      found = Host.find_tagged_with(:any => "red black", :ns => "/test/tags")
      expect(found).to eq([@host1])

      found = Host.find_tagged_with(:any => "black purple", :ns => "/test/tags")
      expect(found).to be_empty
    end

    it ":all" do
      found = Host.find_tagged_with(:all => "red blue", :ns => "/test/tags")
      expect(found).to eq([@host1])

      found = Host.find_tagged_with(:all => "red black", :ns => "/test/tags")
      expect(found).to be_empty
    end

    it "STI classes" do
      vm_template = FactoryGirl.create(:template_vmware, :name => "template", :host => @host)
      vm_template.tag_with("red blue yellow", :ns => "/test", :cat => "tags")

      expect(Vm.find_tagged_with(:all => 'red', :ns => '/test/tags')).to eq([@vm1])
      expect(MiqTemplate.find_tagged_with(:all => 'red', :ns => '/test/tags')).to eq([vm_template])
    end

    it "with namespace specified" do
      expect(Vm.find_tagged_with(:any => "/test/tags/red")).to be_empty
      ["", "*", "none", :none].each do |ns|
        expect(Vm.find_tagged_with(:any => "/test/tags/red", :ns => ns)).to eq([@vm1])
      end

      expect(@vm1.tag_with("123 456 789", :ns => "*")).to eq(["123", "456", "789"])
      ["", "*", "none", :none].each do |ns|
        expect(Vm.find_tagged_with(:all => "123 456 789", :ns => ns)).to eq([@vm1])
      end

      expect(@vm1.tag_with("/managed/location/nyc", :ns => "*")).to eq(["/managed/location/nyc"])
      expect(Vm.find_tagged_with(:all => "/managed/location/nyc", :ns => "")).to eq([@vm1])
      expect(Vm.find_tagged_with(:all => "location/nyc",          :ns => "/managed")).to eq([@vm1])
      expect(Vm.find_tagged_with(:all => "nyc",                   :ns => "/managed/location")).to eq([@vm1])
      expect(Vm.find_tagged_with(:all => "nyc",                   :ns => "/managed", :cat => "location")).to eq([@vm1])
    end
  end

  it "#tags" do
    expect(Host.find_by_name("HOST1").tags.length).to eq(3)
    expect(Vm.find_by_name("VM2").tags.length).to eq(0)
  end

  context "#tag_with" do
    it "passing string" do
      vm = Vm.find_by_name("VM3")
      expect(vm.tag_with("abc def ghi")).to eq(["abc", "def", "ghi"])
      expect(Vm.find_tagged_with(:all => "abc def ghi", :ns => '/user')).to eq([@vm3])
    end

    it "passing array" do
      vm = Vm.find_by_name("VM3")
      expect(vm.tag_with(["abc", "def", "ghi"])).to eq(["abc", "def", "ghi"])
      expect(Vm.find_tagged_with(:all => "abc def ghi", :ns => '/user')).to eq([@vm3])
    end

    context "can remove tags" do
      before do
        @vm2.tag_with("red", :ns => "/test", :cat => "my_zone")
        @vm2.tag_with("low", :ns => "/test", :cat => "my_zone_cost")
      end

      it "should remove tags from the category" do
        @vm2.tag_with("", :ns => "/test", :cat => "my_zone")
        expect(Vm.find_tagged_with(:all => "red", :ns => "/test/my_zone")).to be_empty
      end

      it "should not remove tags from other category" do
        @vm2.tag_with("", :ns => "/test", :cat => "my_zone")
        expect(Vm.find_tagged_with(:all => "low", :ns => "/test/my_zone_cost")).not_to be_empty
      end
    end
  end

  it "#tag_add" do
    vm = Vm.find_by_name("VM1")
    expect(vm.tag_add("abc", :ns => "/test/tags")).to eq(["abc"])
    expect(Vm.find_tagged_with(:all => "red blue yellow abc", :ns => "/test/tags")).to eq([@vm1])
  end

  context "#is_tagged_with?" do
    it "works" do
      vm = Vm.find_by_name("VM1")
      expect(vm.is_tagged_with?("red",   :ns => "/test", :cat => "tags")).to be_truthy
      expect(vm.is_tagged_with?("black", :ns => "/test", :cat => "tags")).not_to be_truthy
    end

    it "works with mixed case" do
      expect(@vm3).to be_is_tagged_with("Red",    :ns => "/Test", :cat => "MixedCase")
      expect(@vm3).to be_is_tagged_with("Blue",   :ns => "/test", :cat => "MixedCase")
      expect(@vm3).to be_is_tagged_with("yellow", :ns => "/Test", :cat => "mixedcase")
      expect(@vm3).to be_is_tagged_with("yellow", :ns => "/test", :cat => "mixedcase")
    end

    it "with namespace specified" do
      expect(@vm1).to be_is_tagged_with("/test/tags/red", :ns => "")
      expect(@vm1).to be_is_tagged_with("/test/tags/red", :ns => "*")
      expect(@vm1).to be_is_tagged_with("/test/tags/red", :ns => "none")
      expect(@vm1).to be_is_tagged_with("/test/tags/red", :ns => :none)
    end
  end

  it "#tag_list" do
    expect(Host.find_by_name("HOST1").tag_list(:ns => "/test", :cat => "tags").split).to match_array %w(red blue yellow)
    expect(Vm.find_by_name("VM1").tag_list(:ns => "/test/tags").split).to match_array %w(red blue yellow)
  end

  it "#to_tag" do
    expect(Tag.to_tag("nyc", :cat => "someuser")).to eq("/user/someuser/nyc")
    expect(Tag.to_tag("/user/bos", :ns => "none")).to eq("/user/bos")
    expect(Tag.to_tag("bos")).to eq("/user/bos")
  end
end
