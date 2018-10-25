describe FileDepotNfs do
  let(:uri)            { "nfs://foo.com/directory" }
  let(:swift_uri)      { "swift://foo_bucket/doo_directory" }
  let(:file_depot_nfs) { FileDepotNfs.new(:uri => uri) }

  it "should return a valid prefix" do
    expect(FileDepotNfs.uri_prefix).to eq "nfs"
  end

  describe "#merged_uri" do
    before do
      file_depot_nfs.uri = uri
    end

    it "should return the uri set on the depot object and ignore the uri parameter" do
      expect(file_depot_nfs.merged_uri(swift_uri, nil)).to eq uri
    end

    it "should return the uri set on the depot object and ignore an empty uri parameter" do
      expect(file_depot_nfs.merged_uri(nil, nil)).to eq uri
    end
  end
end
