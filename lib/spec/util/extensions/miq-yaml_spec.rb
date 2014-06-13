require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-yaml'

# Class to test complex key yaml dump patch
class BaseballTeam
  attr_accessor :name
  def initialize(name); self.name = name; end
end

# Subclass of Hash to test instance variables support patch
class SubHash < Hash
  attr_accessor :val
end

describe YAML do
  it 'Hash#to_yaml without instance variables' do
    h = Hash.new
    h.merge!(:a => 1, :b => 2)

    y = YAML.dump(h)
    y.include?("__iv__").should be_false

    h2 = YAML.load(y)
    h2.should be_instance_of Hash
    h2.should == h
  end

  it 'SubHash#to_yaml with instance variables' do
    h = SubHash.new
    h.merge!(:a => 1, :b => 2)
    h.val = 3

    y = YAML.dump(h)
    y.include?("__iv__@val: 3").should be_true

    h2 = YAML.load(y)
    h2.should be_instance_of SubHash
    h2.should == h
    h2.val.should == 3
  end

  context "with Hash with a complex key" do
    before(:each) do
      @hash = {BaseballTeam.new("New York Mets") => "national"}

      @expected1 = <<-EOL
---
? !ruby/object:BaseballTeam
  name: New York Mets
: national
EOL

      @expected2 = <<-EOL
---
- ? !ruby/object:BaseballTeam
    name: New York Mets
  : national
EOL

      @expected3 = <<-EOL
---
- teams:
    ? !ruby/object:BaseballTeam
      name: New York Mets
    : national
EOL

    end

    it 'Hash#to_yaml' do
      @hash.to_yaml.should == @expected1
    end

    it 'Hash#to_yaml(StringIO)' do
      string_io = StringIO.new
      @hash.to_yaml(string_io)
      string_io.rewind
      string_io.read.should == @expected1
    end

    it 'Array#to_yaml with that Hash' do
      # Test when the complex key is dumped on a line with the "-" from the Array
      [@hash].to_yaml.should == @expected2
    end

    it 'Array#to_yaml with that Hash deep embedded' do
      [{"teams" => @hash}].to_yaml.should == @expected3
    end
  end
end
