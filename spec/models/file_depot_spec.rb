describe FileDepot do
  it ".depot_description_to_class" do
    expect(described_class.depot_description_to_class("FTP")).to eq(FileDepotFtp)
    expect(described_class.depot_description_to_class("NFS")).to eq(FileDepotNfs)
    expect(described_class.depot_description_to_class("Samba")).to eq(FileDepotSmb)
    expect(described_class.depot_description_to_class("Anonymous FTP")).to eq(FileDepotFtpAnonymous)
    expect(described_class.depot_description_to_class("OpenStack Swift")).to eq(FileDepotSwift)
  end
end
