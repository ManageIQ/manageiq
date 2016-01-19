require 'util/extensions/miq-symbol'

describe Symbol do
  it "#to_i" do
    expect(:"1".to_i).to eq(1)
    expect(:"-1".to_i).to eq(-1)
    expect(:test.to_i).to eq(0)
    expect(:test1.to_i).to eq(0)
    expect(:"1test".to_i).to eq(1)
  end
end
