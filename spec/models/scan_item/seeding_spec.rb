require 'fileutils'

RSpec.describe ScanItem do
  describe "::Seeding" do
    include_examples ".seed called multiple times"

    describe ".seed" do
      let(:tmpdir)         { Pathname.new(Dir.mktmpdir) }
      let(:scan_item_dir)  { tmpdir.join("product/scan_items") }
      let(:scan_item_yml)  { scan_item_dir.join("testing_scan_item.yaml") }
      let(:data_dir)       { Pathname.new(__dir__).join("data/product") }

      before do
        FileUtils.mkdir_p(scan_item_dir)
        FileUtils.cp_r(Rails.root.join("product", "scan_items", "scan_item_cat.yaml"), scan_item_dir, :preserve => true)

        stub_const("ScanItem::Seeding::SCAN_ITEMS_DIR", scan_item_dir)
        expect(Vmdb::Plugins).to receive(:flat_map).at_least(:once) { [] }
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it "creates, updates, and changes records" do
        described_class.seed

        orig_scan_item = ScanItem.find_by(:name => "sample_category")
        expect(orig_scan_item).to_not be_nil

        expect(ScanItem.where(:name => "testing_scan_item")).to_not exist

        # Add new records
        FileUtils.cp_r(data_dir, tmpdir, :preserve => true)

        described_class.seed

        scan_item = ScanItem.find_by(:name => "testing_scan_item")

        expect(scan_item).to have_attributes(
          :name         => "testing_scan_item",
          :description  => "Testing ScanItem",
          :filename     => "testing_scan_item.yaml",
          :file_mtime   => File.mtime(scan_item_yml).utc.round,
          :prod_default => "Default",
          :mode         => "Vm",
          :definition   => a_hash_including("content" => include("target" => "vmconfig"))
        )

        # Update reports
        orig_scan_item_mtime = orig_scan_item.file_mtime
        scan_item_mtime = scan_item.file_mtime

        # The mtime rounding is granular to the second, so need to be higher
        # than that for test purposes
        FileUtils.touch(scan_item_yml, :mtime => 1.second.from_now.to_time)

        described_class.seed

        expect(orig_scan_item.reload.file_mtime).to eq(orig_scan_item_mtime)
        expect(scan_item.reload.file_mtime).to_not eq(scan_item_mtime)

        # Delete reports
        FileUtils.rm_f(scan_item_yml)

        described_class.seed

        expect { scan_item.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe ".seed_files (private)" do
    it "will include files from core" do
      expect(described_class.send(:seed_files)).to include(
        a_string_starting_with(Rails.root.join("product", "scan_items").to_s)
      )
    end

    it "will include files from plugins" do
      plugin = Vmdb::Plugins.detect { |p| p.root.join("content/scan_items").exist? }
      skip "no plugin with content exists" unless plugin

      expect(described_class.send(:seed_files)).to include(
        a_string_starting_with(plugin.root.join("content/scan_items").to_s)
      )
    end
  end
end
