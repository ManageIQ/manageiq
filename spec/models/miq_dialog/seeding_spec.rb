require 'fileutils'

RSpec.describe MiqDialog do
  describe "::Seeding" do
    include_examples ".seed called multiple times"

    describe ".seed" do
      let(:tmpdir)     { Pathname.new(Dir.mktmpdir) }
      let(:dialog_dir) { tmpdir.join("product/dialogs/miq_dialogs") }
      let(:dialog_yml) { dialog_dir.join("testing.yaml") }
      let(:data_dir)   { Pathname.new(__dir__).join("data/product") }

      before do
        FileUtils.mkdir_p(dialog_dir)
        FileUtils.cp_r(Rails.root.join("product/dialogs/miq_dialogs/miq_provision_dialogs.yaml"), dialog_dir, preserve: true)

        stub_const("MiqDialog::Seeding::DIALOG_DIR", dialog_dir)
        expect(Vmdb::Plugins).to receive(:flat_map).at_least(:once) { [] }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it "creates, updates, and changes records" do
        described_class.seed

        orig_dialog = MiqDialog.find_by(:name => "miq_provision_dialogs")
        expect(orig_dialog).to_not be_nil

        expect(MiqDialog.where(:name => "testing_dialog")).to_not exist

        # Add new records
        FileUtils.cp_r(data_dir, tmpdir, preserve: true)

        described_class.seed

        dialog = MiqDialog.find_by(:name => "testing_dialog")

        expect(dialog).to have_attributes(
          :name        => "testing_dialog",
          :description => "Testing Dialog",
          :filename    => "testing.yaml",
          :file_mtime  => File.mtime(dialog_yml).utc.round,
          :dialog_type => "MiqProvisionWorkflow",
          :content     => a_hash_including(:dialog_order => %i[requester service])
        )

        # Update reports
        orig_dialog_mtime = orig_dialog.file_mtime
        dialog_mtime = dialog.file_mtime

        # The mtime rounding is granular to the second, so need to be higher
        # than that for test purposes
        FileUtils.touch(dialog_yml, mtime: 1.second.from_now.to_time)

        described_class.seed

        expect(orig_dialog.reload.file_mtime).to eq(orig_dialog_mtime)
        expect(dialog.reload.file_mtime).to_not eq(dialog_mtime)

        # Delete reports
        FileUtils.rm_f(dialog_yml)

        described_class.seed

        expect { dialog.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe ".seed_files (private)" do
    it "will include files from core" do
      expect(described_class.send(:seed_files)).to include(
        a_string_starting_with(Rails.root.join("product/dialogs/miq_dialogs").to_s)
      )
    end

    it "will include files from a plugin" do
      plugin = Vmdb::Plugins.detect { |p| p.root.join("content/miq_dialogs").exist? }
      skip "no plugin with content exists" unless plugin

      expect(described_class.send(:seed_files)).to include(
        a_string_starting_with(plugin.root.join("content/miq_dialogs").to_s)
      )
    end
  end
end
