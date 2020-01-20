$LOAD_PATH << Rails.root.join("tools").to_s

require 'pg_inspector'

RSpec.describe PgInspector::ActiveConnectionsHumanYAML do
  it "#compress_id" do
    subject = described_class.new
    expect(subject.send(:compress_id, 5)).to eq("5")
    expect(subject.send(:compress_id, 1_000_000_000_005)).to eq("1r5")
    expect(subject.send(:compress_id, 2_000_000_000_005)).to eq("2r5")
  end

  it "#uncompress_id" do
    subject = described_class.new
    expect(subject.send(:uncompress_id, "5")).to eq(5)
    expect(subject.send(:uncompress_id, "1r5")).to eq(1_000_000_000_005)
    expect(subject.send(:uncompress_id, "2r5")).to eq(2_000_000_000_005)
  end
end
