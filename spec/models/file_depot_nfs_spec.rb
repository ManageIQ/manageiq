RSpec.describe FileDepotNfs do
  let(:uri)            { "nfs://ignore.com/directory" }
  let(:actual_uri)     { "nfs://actual_bucket/doo_directory" }
  let(:file_depot_nfs) { FileDepotNfs.new(:uri => uri) }

  it "should return a valid prefix" do
    expect(FileDepotNfs.uri_prefix).to eq "nfs"
  end

  describe "#merged_uri" do
    before do
      file_depot_nfs.uri = uri
    end

    it "should ignore the uri set on the depot object and return the uri parameter" do
      expect(file_depot_nfs.merged_uri(actual_uri, nil)).to eq actual_uri
    end
  end
end
