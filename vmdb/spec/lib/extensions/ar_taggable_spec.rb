
require "spec_helper"

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
      found.should == [@host1]

      found = Host.find_tagged_with(:any => "black purple", :ns => "/test/tags")
      found.should be_empty
    end

    it ":all" do
      found = Host.find_tagged_with(:all => "red blue", :ns => "/test/tags")
      found.should == [@host1]

      found = Host.find_tagged_with(:all => "red black", :ns => "/test/tags")
      found.should be_empty
    end

    it "STI classes" do
      vm_template = FactoryGirl.create(:template_vmware, :name => "template", :host => @host)
      vm_template.tag_with("red blue yellow", :ns => "/test", :cat => "tags")

      Vm.find_tagged_with(:all => 'red', :ns => '/test/tags').should == [@vm1]
      MiqTemplate.find_tagged_with(:all => 'red', :ns => '/test/tags').should == [vm_template]
    end

    it "with namespace specified" do
      Vm.find_tagged_with(:any => "/test/tags/red").should be_empty
      ["", "*", "none", :none].each do |ns|
        Vm.find_tagged_with(:any => "/test/tags/red", :ns => ns).should == [@vm1]
      end

      @vm1.tag_with("123 456 789", :ns=>"*").should == ["123", "456", "789"]
      ["", "*", "none", :none].each do |ns|
        Vm.find_tagged_with(:all => "123 456 789", :ns => ns).should == [@vm1]
      end

      @vm1.tag_with("/managed/location/nyc", :ns=>"*").should == ["/managed/location/nyc"]
      Vm.find_tagged_with(:all => "/managed/location/nyc", :ns => "").should == [@vm1]
      Vm.find_tagged_with(:all => "location/nyc",          :ns => "/managed").should == [@vm1]
      Vm.find_tagged_with(:all => "nyc",                   :ns => "/managed/location").should == [@vm1]
      Vm.find_tagged_with(:all => "nyc",                   :ns => "/managed", :cat => "location").should == [@vm1]
    end
  end

  it "#tags" do
    Host.find_by_name("HOST1").tags.length.should == 3
    Vm.find_by_name("VM2").tags.length.should     == 0
  end

  context "#tag_with" do
    it "passing string" do
      vm = Vm.find_by_name("VM3")
      vm.tag_with("abc def ghi").should == ["abc", "def", "ghi"]
      Vm.find_tagged_with(:all => "abc def ghi", :ns => '/user').should == [@vm3]
    end

    it "passing array" do
      vm = Vm.find_by_name("VM3")
      vm.tag_with(["abc", "def", "ghi"]).should == ["abc", "def", "ghi"]
      Vm.find_tagged_with(:all => "abc def ghi", :ns => '/user').should == [@vm3]
    end

    context "can remove tags" do
      before do
        @vm2.tag_with("red", :ns => "/test", :cat => "my_zone")
        @vm2.tag_with("low", :ns => "/test", :cat => "my_zone_cost")
      end

      it "should remove tags from the category" do
        @vm2.tag_with("", :ns => "/test", :cat => "my_zone")
        Vm.find_tagged_with(:all => "red", :ns => "/test/my_zone").should be_empty
      end
       
      it "should not remove tags from other category" do
        @vm2.tag_with("", :ns => "/test", :cat => "my_zone")
        Vm.find_tagged_with(:all => "low", :ns => "/test/my_zone_cost").should_not be_empty
      end
    end
  end

  it "#tag_add" do
    vm = Vm.find_by_name("VM1")
    vm.tag_add("abc", :ns => "/test/tags").should == ["abc"]
    Vm.find_tagged_with(:all => "red blue yellow abc", :ns => "/test/tags").should == [@vm1]
  end

  context "#is_tagged_with?" do
    it "works" do
      vm = Vm.find_by_name("VM1")
      vm.is_tagged_with?("red",   :ns => "/test", :cat => "tags").should be_true
      vm.is_tagged_with?("black", :ns => "/test", :cat => "tags").should_not be_true
    end

    it "works with mixed case" do
      @vm3.should be_is_tagged_with("Red",    :ns => "/Test", :cat => "MixedCase")
      @vm3.should be_is_tagged_with("Blue",   :ns => "/test", :cat => "MixedCase")
      @vm3.should be_is_tagged_with("yellow", :ns => "/Test", :cat => "mixedcase")
      @vm3.should be_is_tagged_with("yellow", :ns => "/test", :cat => "mixedcase")
    end

    it "with namespace specified" do
      @vm1.should be_is_tagged_with("/test/tags/red", :ns => "")
      @vm1.should be_is_tagged_with("/test/tags/red", :ns => "*")
      @vm1.should be_is_tagged_with("/test/tags/red", :ns => "none")
      @vm1.should be_is_tagged_with("/test/tags/red", :ns => :none)
    end
  end

  it "#tag_list" do
    Host.find_by_name("HOST1").tag_list(:ns => "/test", :cat => "tags").split.should have_same_elements %w{red blue yellow}
    Vm.find_by_name("VM1").tag_list(:ns => "/test/tags").split.should have_same_elements %w{red blue yellow}
  end

  it "#to_tag" do
    Tag.to_tag("nyc", :cat => "someuser").should == "/user/someuser/nyc"
    Tag.to_tag("/user/bos", :ns => "none").should == "/user/bos"
    Tag.to_tag("bos").should == "/user/bos"
  end
end
