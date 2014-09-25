require 'spec_helper'
require 'ec2Extract/Ec2Payload'

describe Ec2Payload do
  it "GLOBAL_KEY treated as binary" do
    binary_key = "\222dL\256\177\311X)\177\332\214*3\367\252\002\023\034\305\243\274\252\312X\276\b\273\261\331(\216\310".force_encoding("ASCII-8BIT")
    expect(described_class::GLOBAL_KEY).to eq binary_key
  end
end
