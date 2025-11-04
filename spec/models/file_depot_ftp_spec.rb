RSpec.describe FileDepotFtp do
  let(:uri)            { "ftp://server.example.com/uploads" }
  let(:file_depot_ftp) { FileDepotFtp.new(:uri => uri) }

  context "#merged_uri" do
    before do
      file_depot_ftp.uri = uri
    end

    it "should ignore the uri attribute from the file depot object and return the parameter" do
      expect(file_depot_ftp.merged_uri(nil, nil)).to eq nil
    end
  end
end
