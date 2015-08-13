require "spec_helper"
require 'util/extensions/miq-yaml'

# Subclass of Hash to test instance variables support patch
class SubHash < Hash
  attr_accessor :val
end

describe YAML do
  it 'loads the old ivar format' do
    hash = YAML.load <<-eoyml
--- !ruby/hash:SubHash
:a: 1
:b: 2
__iv__@val: 3
eoyml
    hash[:a].should == 1
    hash[:b].should == 2
    hash.val.should == 3
  end
end
