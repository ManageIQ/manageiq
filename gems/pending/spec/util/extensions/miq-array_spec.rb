require 'util/extensions/miq-string'
require 'util/extensions/miq-array'

describe NilClass do
  it '#to_miq_a' do
    expect(nil.to_miq_a).to eq([])
    expect(nil.to_miq_a).to eq(Array.wrap(nil))
  end
end

describe Hash do
  it '#to_miq_a' do
    expect({}.to_miq_a).to eq([{}])
    expect({}.to_miq_a).to eq(Array.wrap({}))
  end
end

describe String do
  context "#to_miq_a" do
    it 'normal' do
      # NOTE: this differs from Array.wrap
      expect("onetwo".to_miq_a).to eq(["onetwo"])
    end

    it 'with an empty string' do
      # NOTE: this differs from Array.wrap
      expect("".to_miq_a).to eq([])
    end

    it 'with newlines' do
      # NOTE: this differs from Array.wrap
      expect("one\ntwo".to_miq_a).to eq(["one\n", "two"])
    end
  end
end

describe Array do
  it "#to_miq_a" do
    expect([].to_miq_a).to eq([])
    expect([[]].to_miq_a).to eq([[]])
    expect([].to_miq_a).to eq(Array.wrap([]))
    expect([[]].to_miq_a).to eq(Array.wrap([[]]))
  end
end
