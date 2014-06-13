require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
require 'miq-hash_struct'

describe MiqHashStruct do
  it ".new" do
    m = MiqHashStruct.new()
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
    m = MiqHashStruct.new({"test1" => "ok"})
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
    m = MiqHashStruct.new({:test1 => "ok"})
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
    lambda { MiqHashStruct.new(["test1"]) }.should raise_error(ArgumentError)
  end

  it ".new with invalid argument (non-String/Symbol keys)" do
    lambda { MiqHashStruct.new({["test1"] => "ok"}) }.should raise_error(ArgumentError)
  end

  it '#send with String keys' do
    m = MiqHashStruct.new({"test1" => "ok"})
    m.send('test1').should == "ok"
    m.send(:test1).should  == "ok"
    m.send('test2').should be_nil
    m.send(:test2).should  be_nil
  end

  it '#send with Symbol keys' do
    m = MiqHashStruct.new({:test1 => "ok"})
    m.send('test1').should == "ok"
    m.send(:test1).should  == "ok"
    m.send('test2').should be_nil
    m.send(:test2).should  be_nil
  end

  it '#id when Hash has a key of :id' do
    m = MiqHashStruct.new({:id => "test_id"})
    m.id.should == "test_id"
  end

  it '#id when Hash does not have a key of :id' do
    m = MiqHashStruct.new({:no_id => "test_id"})
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
end
