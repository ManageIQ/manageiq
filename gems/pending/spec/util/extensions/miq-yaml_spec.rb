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
    expect(hash[:a]).to eq(1)
    expect(hash[:b]).to eq(2)
    expect(hash.val).to eq(3)
  end
end
