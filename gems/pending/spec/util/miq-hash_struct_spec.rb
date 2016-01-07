require "spec_helper"
require 'util/miq-hash_struct'

describe MiqHashStruct do
  it ".new" do
    m = MiqHashStruct.new
    expect(m._key_type).to eq(Symbol)

    expect(m.test1).to be_nil
    expect(m.test2).to be_nil

    m.test2 = "ok2"
    expect(m.test1).to be_nil
    expect(m.test2).to eq("ok2")

    [Symbol, String, Symbol].each do |typ|
      m._key_type = typ
      expect(m.test1).to be_nil
      expect(m.test2).to eq("ok2")
    end
  end

  it ".new with Hash with String keys" do
    m = MiqHashStruct.new("test1" => "ok")
    expect(m._key_type).to eq(String)

    expect(m.test1).to eq("ok")
    expect(m.test2).to be_nil

    m.test2 = "ok2"
    expect(m.test1).to eq("ok")
    expect(m.test2).to eq("ok2")

    [String, Symbol, String].each do |typ|
      m._key_type = typ
      expect(m.test1).to eq("ok")
      expect(m.test2).to eq("ok2")
      expect(m.test3).to be_nil
    end
  end

  it ".new with Hash with Symbol keys" do
    m = MiqHashStruct.new(:test1 => "ok")
    expect(m._key_type).to eq(Symbol)

    expect(m.test1).to eq("ok")
    expect(m.test2).to be_nil

    m.test2 = "ok2"
    expect(m.test1).to eq("ok")
    expect(m.test2).to eq("ok2")

    [Symbol, String, Symbol].each do |typ|
      m._key_type = typ
      expect(m.test1).to eq("ok")
      expect(m.test2).to eq("ok2")
      expect(m.test3).to be_nil
    end
  end

  it ".new with invalid argument (non-Hash)" do
    expect { MiqHashStruct.new(["test1"]) }.to raise_error(ArgumentError)
  end

  it ".new with invalid argument (non-String/Symbol keys)" do
    expect { MiqHashStruct.new(["test1"] => "ok") }.to raise_error(ArgumentError)
  end

  it '#send with String keys' do
    m = MiqHashStruct.new("test1" => "ok")
    expect(m.send('test1')).to eq("ok")
    expect(m.send(:test1)).to eq("ok")
    expect(m.send('test2')).to be_nil
    expect(m.send(:test2)).to  be_nil
  end

  it '#send with Symbol keys' do
    m = MiqHashStruct.new(:test1 => "ok")
    expect(m.send('test1')).to eq("ok")
    expect(m.send(:test1)).to eq("ok")
    expect(m.send('test2')).to be_nil
    expect(m.send(:test2)).to  be_nil
  end

  it '#id when Hash has a key of :id' do
    m = MiqHashStruct.new(:id => "test_id")
    expect(m.id).to eq("test_id")
  end

  it '#id when Hash does not have a key of :id' do
    m = MiqHashStruct.new(:no_id => "test_id")
    expect(m.id).to be_nil
  end

  context "#==" do
    let(:test_struct) { MiqHashStruct.new(:number => 1, :string => "test") }

    it "with a matching miq-hash_struct" do
      matching = MiqHashStruct.new(:number => 1, :string => "test")
      expect(test_struct).to eq(matching)
    end

    it "with a non-matching miq-hash_struct" do
      non_matching = MiqHashStruct.new(:number => 2, :string => "test")
      expect(test_struct).not_to eq(non_matching)
    end

    it "with a different object class" do
      expect(test_struct).not_to eq("string")
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

  context '#respond_to?' do
    let(:hs) { MiqHashStruct.new(:foo => 1) }

    it "getter with existing key" do
      expect(hs.respond_to?(:foo)).to eq(true)
    end

    it "setter with existing key" do
      expect(hs.respond_to?(:foo=)).to eq(true)
    end

    it "getter with unknown key" do
      expect(hs.respond_to?(:bar)).to eq(false)
    end

    it "setter with unknown key" do
      expect(hs.respond_to?(:bar=)).to eq(true)
    end
  end

  context "dump and load" do
    let (:orig) { described_class.new("a" => 1, "b" => 2) }

    it("Marshal") { expect(Marshal.load(Marshal.dump(orig))).to eq(orig) }
    it("YAML")    { expect(YAML.load(YAML.dump(orig))).to       eq(orig) }
  end
end
