describe FileDepotNfs do
  let(:uri)           { "nfs://foo.com/directory" }
  let(:file_depot_nfs) { FileDepotNfs.new(:uri => uri) }

  it "should return a valid prefix" do
    expect(FileDepotNfs.uri_prefix).to eq "nfs"
  end

  describe "#merged_uri" do
    it "should return the same uri submitted" do
      expect(file_depot_nfs.merged_uri(uri, nil)).to eq uri
    end
  end
end
