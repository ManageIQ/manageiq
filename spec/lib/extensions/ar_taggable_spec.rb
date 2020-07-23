RSpec.describe ActsAsTaggable do
  before do
    @host1 = FactoryBot.create(:host, :name => "HOST1")
    @host1.tag_with("red blue yellow", :ns => "/test", :cat => "tags")
    @host2 = FactoryBot.create(:host, :name => "HOST2")
    @host3 = FactoryBot.create(:host, :name => "HOST3")

    @vm1   = FactoryBot.create(:vm_vmware, :name => "VM1")
    @vm2   = FactoryBot.create(:vm_vmware, :name => "VM2")
    @vm3   = FactoryBot.create(:vm_vmware, :name => "VM3")
    @vm4   = FactoryBot.create(:vm_vmware, :name => "VM4")

    @vm1.tag_with("red blue yellow", :ns => "/test", :cat => "tags")
    @vm3.tag_with("Red Blue Yellow", :ns => "/Test", :cat => "MixedCase")
    @vm4.tag_with("nyc chi la", :cat => "someuser")
    @vm4.tag_add("bos phi blt")
  end

  describe '#writable_classification_tags' do
    let(:parent_classification) { FactoryBot.create(:classification, :description => "Environment", :name => "environment", :read_only => false) }
    let(:classification)        { FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent => parent_classification, :read_only => true) }

    before do
      classification.assign_entry_to(@vm1)
    end

    it "returns only tags as they would be entered in UI by user(edit tags screen)" do
      expect(@vm1.tags.count).to eq(4)
      expect(@vm1.writable_classification_tags.count).to eq(1)
      expect(@vm1.writable_classification_tags.first.name).to eq('/managed/environment/prod')
      expect(@vm1.writable_classification_tags.first).to be_kind_of(Tag)

      expect(@vm3.writable_classification_tags.count).to eq(0)
      expect(@vm3.tags.count).to eq(3)
    end
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
      vm_template = FactoryBot.create(:template_vmware, :name => "template", :host => @host)
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
    expect(Host.find_by(:name => "HOST1").tags.length).to eq(3)
    expect(Vm.find_by(:name => "VM2").tags.length).to eq(0)
  end

  context "#tag_with" do
    it "passing string" do
      vm = Vm.find_by(:name => "VM3")
      expect(vm.tag_with("abc def ghi")).to eq(["abc", "def", "ghi"])
      expect(Vm.find_tagged_with(:all => "abc def ghi", :ns => '/user')).to eq([@vm3])
    end

    it "passing array" do
      vm = Vm.find_by(:name => "VM3")
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
    vm = Vm.find_by(:name => "VM1")
    expect(vm.tag_add("abc", :ns => "/test/tags")).to eq(["abc"])
    expect(Vm.find_tagged_with(:all => "red blue yellow abc", :ns => "/test/tags")).to eq([@vm1])
  end

  context "#tag_remove" do
    it "works" do
      vm = Vm.find_by(:name => "VM1")
      vm.tag_add("foo1", :ns => "/test/tags")
      vm.tag_add("foo2", :ns => "/test/tags")
      expect(vm.tag_remove("foo1", :ns => "/test/tags")).to eq(["foo1"])
      expect(Vm.find_tagged_with(:all => "foo2", :ns => "/test/tags")).to eq([@vm1])
      expect(Vm.find_tagged_with(:all => "foo1", :ns => "/test/tags")).to be_empty
    end

    it "does nothing if tag doesn't exist" do
      vm = Vm.find_by(:name => "VM1")
      vm.tag_remove("foo3", :ns => "/test/tags")
      expect(Tag.find_by(:name => "/test/tags/foo3")).to be_nil
      expect(Vm.find_tagged_with(:all => "foo3", :ns => "/test/tags")).to be_empty
    end
  end

  context "#is_tagged_with?" do
    it "works" do
      vm = Vm.find_by(:name => "VM1")
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

    it "with virtual reflections" do
      lan = FactoryBot.create(:lan, :name => "VM NFS Network")
      vm  = FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [FactoryBot.create(:guest_device_nic, :lan => lan)]))
      expect(vm).to be_is_tagged_with("/virtual/lans/name/VM NFS Network", :ns => "*")
    end
  end

  describe "#tag_attribute" do
    before do
      class TestModel < ApplicationRecord
        self.table_name = "hosts"
      end
    end

    after do
      Object.send(:remove_const, :TestModel)
    end

    it "doesn't have a tag method" do
      expect(TestModel.respond_to?(:tag_attribute)).to be(false)
    end

    it "can't declare detect tag" do
      TestModel.acts_as_miq_taggable
      expect(TestModel.respond_to?(:tag_attribute)).to be(true)
    end

    let(:franchise)      { FactoryBot.create(:classification,     :name => "franchise") }
    let(:posh_franchise) { FactoryBot.create(:classification_tag, :name => "posh", :parent => franchise) }
    let(:location)       { FactoryBot.create(:classification,     :name => "location") }
    let(:south_location) { FactoryBot.create(:classification_tag, :name => "south", :parent => location) }

    it "detects tags" do
      TestModel.destroy_all
      TestModel.acts_as_miq_taggable
      TestModel.tag_attribute :franchise, franchise.tag.name

      none  = TestModel.create
      south = TestModel.create(:tags => [south_location.tag])
      posh  = TestModel.create(:tags => [posh_franchise.tag])

      expect(none.has_franchises?).to be(false)
      expect(south.has_franchises?).to be(false)
      expect(posh.has_franchises?).to be(true)

      expect(TestModel.order(:id).select(:id, :has_franchises).map(&:has_franchises?)).to eq([false, false, true])
    end
  end

  it "#tag_list" do
    expect(Host.find_by(:name => "HOST1").tag_list(:ns => "/test", :cat => "tags").split).to match_array %w(red blue yellow)
    expect(Vm.find_by(:name => "VM1").tag_list(:ns => "/test/tags").split).to match_array %w(red blue yellow)
  end

  it "#to_tag" do
    expect(Tag.to_tag("nyc", :cat => "someuser")).to eq("/user/someuser/nyc")
    expect(Tag.to_tag("/user/bos", :ns => "none")).to eq("/user/bos")
    expect(Tag.to_tag("bos")).to eq("/user/bos")
  end
end
