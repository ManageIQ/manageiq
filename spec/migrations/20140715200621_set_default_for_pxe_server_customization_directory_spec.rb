require_migration

describe SetDefaultForPxeServerCustomizationDirectory do
  let(:pxe_server_stub) { migration_stub(:PxeServer) }

  migration_context :up do
    it "Sets customization_directory to '' if nil" do
      pxe_server_stub.create!(:name => "pxe_server_a", :uri => "nfs://example.com/share")

      expect(PxeServer.count).to eq(1)

      migrate

      expect(pxe_server_stub.first.customization_directory).to eq('')
    end
  end
end
