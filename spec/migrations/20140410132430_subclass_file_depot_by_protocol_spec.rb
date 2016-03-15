require_migration

describe SubclassFileDepotByProtocol do
  let(:file_depot_stub) { migration_stub(:FileDepot) }

  migration_context :up do
    it "Sets type on existing FileDepot records" do
      ["ftp", "nfs", "smb"].each { |type| file_depot_stub.create!(:name => "#{type} depot", :uri => "#{type}://example.com/share") }

      expect(file_depot_stub.count).to eq(3)

      migrate

      expect(file_depot_stub.where(:type => "FileDepotFtp").count).to eq(1)
      expect(file_depot_stub.where(:type => "FileDepotNfs").count).to eq(1)
      expect(file_depot_stub.where(:type => "FileDepotSmb").count).to eq(1)
    end

    it "Removes invalid records" do
      [nil, "", "aaa"].each { |type| file_depot_stub.create!(:uri => type) }

      expect(file_depot_stub.count).to eq(3)

      migrate

      expect(file_depot_stub.count).to eq(0)
    end
  end
end
