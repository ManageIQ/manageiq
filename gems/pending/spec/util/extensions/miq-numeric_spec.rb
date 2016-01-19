require 'util/extensions/miq-numeric'

describe Numeric do
  it "#apply_min_max" do
    expect(8.apply_min_max(nil, nil)).to eq(8)
    expect(8.apply_min_max(3, nil)).to eq(8)
    expect(8.apply_min_max(13, nil)).to eq(13)
    expect(8.apply_min_max(nil, 6)).to eq(6)
    expect(8.apply_min_max(13, 16)).to eq(13)
    expect(20.apply_min_max(13, 16)).to eq(16)

    expect(8.0.apply_min_max(nil, nil)).to eq(8.0)
    expect(8.0.apply_min_max(3.0, nil)).to eq(8.0)
    expect(8.0.apply_min_max(13.0, nil)).to eq(13.0)
    expect(8.0.apply_min_max(nil, 6.0)).to eq(6.0)
    expect(8.0.apply_min_max(13.0, 16.0)).to eq(13.0)
    expect(20.0.apply_min_max(13.0, 16.0)).to eq(16.0)
  end
end
