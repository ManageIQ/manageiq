describe FileDepotSwift do
  let(:uri) { "swift://server.example.com/bucket" }
  let(:merged_uri) { "swift://server.example.com:5678/bucket?region=test_openstack_region&api_version=v3&domain_id=default" }
  let(:merged_default_uri) { "swift://server.example.com:5000/bucket?region=test_openstack_region&api_version=v3&domain_id=default" }
  let(:file_depot_swift) { FileDepotSwift.new(:uri => uri) }
  it "should require credentials" do
    expect(FileDepotSwift.requires_credentials?).to eq true
  end

  it "should return a valid prefix" do
    expect(FileDepotSwift.uri_prefix).to eq "swift"
  end

  describe "#merged_uri" do
    before do
      file_depot_swift.openstack_region = "test_openstack_region"
      file_depot_swift.keystone_api_version = "v3"
      file_depot_swift.v3_domain_ident = "default"
    end

    it "should return a merged uri with query strings given an empty port" do
      expect(file_depot_swift.merged_uri(uri, nil)).to eq merged_default_uri
    end 

    it "should return a merged uri with query strings when given a valid port" do
      expect(file_depot_swift.merged_uri(uri, "5678")).to eq merged_uri
    end 
  end
end
