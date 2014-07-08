require "spec_helper"
require Rails.root.join("db/migrate/20140410132430_subclass_file_depot_by_protocol")

describe SubclassFileDepotByProtocol do
  let(:file_depot_stub) { migration_stub(:FileDepot) }

  migration_context :up do
    it "Sets type on existing FileDepot records" do
      ["ftp", "nfs", "smb"].each { |type| file_depot_stub.create!(:name => "#{type} depot", :uri => "#{type}://example.com/share") }

      expect(FileDepot.count).to eq(3)

      migrate

      expect(file_depot_stub.where(:type => "FileDepotFtp").count).to eq(1)
      expect(file_depot_stub.where(:type => "FileDepotNfs").count).to eq(1)
      expect(file_depot_stub.where(:type => "FileDepotSmb").count).to eq(1)
    end

    it "Removes invalid records" do
      [nil, "", "aaa"].each { |type| file_depot_stub.create!(:uri => type) }

      expect(FileDepot.count).to eq(3)

      migrate

      expect(FileDepot.count).to eq(0)
    end
  end
end
