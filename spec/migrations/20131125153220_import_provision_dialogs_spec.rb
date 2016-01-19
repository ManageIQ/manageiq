require_migration

describe ImportProvisionDialogs do
  let(:miq_dialog_stub) { migration_stub(:MiqDialog) }

  migration_context :up do
    before do
      dialog_file = File.join(File.dirname(__FILE__), "data/20131125153220_import_provision_dialogs_spec/miq_provision_dialogs.rb")
      allow(Dir).to receive(:glob).and_yield(dialog_file)
    end

    it "import dialog file into database" do
      migrate

      expect(miq_dialog_stub.count).to eq(1)

      dialog = miq_dialog_stub.first
      expect(dialog.name).to eq("miq_provision_dialogs")
      expect(dialog.dialog_type).to eq("MiqProvisionWorkflow")
      expect(dialog.default).to           be_falsey
      expect(dialog.content).to           be_kind_of(Hash)
      expect(dialog.content).to           include(:dialog_order, :buttons, :dialogs)
      expect(dialog.content[:buttons]).to include(:submit, :cancel)
    end

    it "skip dialog file if already in database" do
      miq_dialog_stub.create!(:name => "miq_provision_dialogs")
      expect(miq_dialog_stub).to receive(:create).never

      migrate
    end
  end
end
