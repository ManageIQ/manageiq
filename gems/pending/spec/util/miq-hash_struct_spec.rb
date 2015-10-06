require "spec_helper"
require 'util/miq-hash_struct'

describe MiqHashStruct do
  it ".new" do
    m = MiqHashStruct.new
    m._key_type.should == Symbol

    m.test1.should be_nil
    m.test2.should be_nil

    m.test2 = "ok2"
    m.test1.should be_nil
    m.test2.should == "ok2"

    [Symbol, String, Symbol].each do |typ|
      m._key_type = typ
      m.test1.should be_nil
      m.test2.should == "ok2"
    end
  end

  it ".new with Hash with String keys" do
    m = MiqHashStruct.new("test1" => "ok")
    m._key_type.should == String

    m.test1.should == "ok"
    m.test2.should be_nil

    m.test2 = "ok2"
    m.test1.should == "ok"
    m.test2.should == "ok2"

    [String, Symbol, String].each do |typ|
      m._key_type = typ
      m.test1.should == "ok"
      m.test2.should == "ok2"
      m.test3.should be_nil
    end
  end

  it ".new with Hash with Symbol keys" do
    m = MiqHashStruct.new(:test1 => "ok")
    m._key_type.should == Symbol

    m.test1.should == "ok"
    m.test2.should be_nil

    m.test2 = "ok2"
    m.test1.should == "ok"
    m.test2.should == "ok2"

    [Symbol, String, Symbol].each do |typ|
      m._key_type = typ
      m.test1.should == "ok"
      m.test2.should == "ok2"
      m.test3.should be_nil
    end
  end

  it ".new with invalid argument (non-Hash)" do
    -> { MiqHashStruct.new(["test1"]) }.should raise_error(ArgumentError)
  end

  it ".new with invalid argument (non-String/Symbol keys)" do
    -> { MiqHashStruct.new(["test1"] => "ok") }.should raise_error(ArgumentError)
  end

  it '#send with String keys' do
    m = MiqHashStruct.new("test1" => "ok")
    m.send('test1').should == "ok"
    m.send(:test1).should == "ok"
    m.send('test2').should be_nil
    m.send(:test2).should  be_nil
  end

  it '#send with Symbol keys' do
    m = MiqHashStruct.new(:test1 => "ok")
    m.send('test1').should == "ok"
    m.send(:test1).should == "ok"
    m.send('test2').should be_nil
    m.send(:test2).should  be_nil
  end

  it '#id when Hash has a key of :id' do
    m = MiqHashStruct.new(:id => "test_id")
    m.id.should == "test_id"
  end

  it '#id when Hash does not have a key of :id' do
    m = MiqHashStruct.new(:no_id => "test_id")
    m.id.should be_nil
  end

  context "#==" do
    let(:test_struct) { MiqHashStruct.new(:number => 1, :string => "test") }

    it "with a matching miq-hash_struct" do
      matching = MiqHashStruct.new(:number => 1, :string => "test")
      test_struct.should == matching
    end

    it "with a non-matching miq-hash_struct" do
      non_matching = MiqHashStruct.new(:number => 2, :string => "test")
      test_struct.should_not == non_matching
    end

    it "with a different object class" do
      test_struct.should_not == "string"
    end
  end

  context "#try" do
    let(:hs) { MiqHashStruct.new(:id => 1) }

    it("with existing key") { expect(hs.try(:id)).to        eq(1) }
    it("with missing key")  { expect(hs.try(:abc)).to       be_nil }
    it("with :object_id")   { expect(hs.try(:object_id)).to be_kind_of(Integer) }

    it "storing data" do
      hs.try(:abc=, 123)
      expect(hs.to_hash[:abc]).to eq(123)
    end
  end

  context "dump and load" do
    let (:orig) { described_class.new("a" => 1, "b" => 2) }

    it("Marshal") { expect(Marshal.load(Marshal.dump(orig))).to eq(orig) }
    it("YAML")    { expect(YAML.load(YAML.dump(orig))).to       eq(orig) }
  end
end
