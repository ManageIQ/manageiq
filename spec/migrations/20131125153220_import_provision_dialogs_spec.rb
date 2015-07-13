require "spec_helper"

require Rails.root.join("db/migrate/20131125153220_import_provision_dialogs.rb")

describe ImportProvisionDialogs do
  let(:miq_dialog_stub) { migration_stub(:MiqDialog) }

  migration_context :up do
    before do
      dialog_file = File.join(File.dirname(__FILE__), "data/20131125153220_import_provision_dialogs_spec/miq_provision_dialogs.rb")
      Dir.stub(:glob).and_yield(dialog_file)
    end

    it "import dialog file into database" do
      migrate

      miq_dialog_stub.count.should == 1

      dialog = miq_dialog_stub.first
      dialog.name.should              == "miq_provision_dialogs"
      dialog.dialog_type.should       == "MiqProvisionWorkflow"
      dialog.default.should           be_false
      dialog.content.should           be_kind_of(Hash)
      dialog.content.should           include(:dialog_order, :buttons, :dialogs)
      dialog.content[:buttons].should include(:submit, :cancel)
    end

    it "skip dialog file if already in database" do
      miq_dialog_stub.create!(:name => "miq_provision_dialogs")
      miq_dialog_stub.should_receive(:create).never

      migrate
    end
  end

end
