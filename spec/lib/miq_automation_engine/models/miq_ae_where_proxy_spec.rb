require 'spec_helper'

describe MiqAeWhereProxy do
  before do
    TestClass = Class.new do
    end
    Customer = Struct.new(:name, :state, :age)
  end

  after do
    Object.send(:remove_const, :TestClass)
    Object.send(:remove_const, :Customer)
  end


  context "where" do
    before do
      @objs = [Customer.new("Barney", "NY", 45),
               Customer.new("Krueger",  "AL", 56),
               Customer.new("fred",   "AL", 56),
               Customer.new("FREDDY", "NY", 12),
               Customer.new("WILMA",  "NY", 23)]
      TestClass.stub(:find_all_by_name).and_return(@objs)
    end

    it "invalid key should raise an error" do
      where = MiqAeWhereProxy.new(TestClass, :city => "NY").order('age desc')
      expect { where.collect(&:age) }.to raise_error
    end

    it "filtered by state ordered by descending age" do
      where = MiqAeWhereProxy.new(TestClass, :state => "NY").order('age desc')
      where.collect(&:age).should == [45,23,12]
    end

    it "filtered by state ordered by ascending age" do
      where = MiqAeWhereProxy.new(TestClass, :state => "NY").order('age')
      where.collect(&:age).should == [12,23,45]
    end

    it "no filtering ordered by name" do
      where = MiqAeWhereProxy.new(TestClass).order('name')
      where.collect(&:name).should  == (%w(Barney FREDDY Krueger WILMA fred))
    end

    it "no filtering ordered by lower case name" do
      where = MiqAeWhereProxy.new(TestClass).order('lower(name)')
      where.collect(&:name).should  == (%w(Barney fred FREDDY Krueger WILMA))
    end

    it "no filtering ordered by upper case name" do
      where = MiqAeWhereProxy.new(TestClass).order('upper(name)')
      where.collect(&:name).should  == (%w(Barney fred FREDDY Krueger WILMA))
    end

    it "no filtering ordered by non existent method" do
      expect { MiqAeWhereProxy.new(TestClass).order('upper_case(name)') }.to raise_error
    end

  end

end
