RSpec.describe Disk do
  include Spec::Support::ArelHelper

  describe ".used_disk_storage" do
    context "with nothing" do
      let(:disk) { FactoryBot.build(:disk) }

      it "calculates in ruby" do
        expect(disk.used_disk_storage).to eq(0)
      end

      it "calculates in the database" do
        disk.save!
        expect(virtual_column_sql_value(Disk, "used_disk_storage")).to eq(0)
      end
    end

    context "with size" do
      let(:disk) { FactoryBot.build(:disk, :size => 1024) }

      it "calculates in ruby" do
        expect(disk.used_disk_storage).to eq(1024)
      end

      it "calculates in the database" do
        disk.save!
        expect(virtual_column_sql_value(Disk, "used_disk_storage")).to eq(1024)
      end
    end

    context "with size_on_disk" do
      let(:disk) { FactoryBot.build(:disk, :size_on_disk => 1024, :size => 10240) }

      it "calculates in ruby" do
        expect(disk.used_disk_storage).to eq(1024)
      end

      it "calculates in the database" do
        disk.save!
        expect(virtual_column_sql_value(Disk, "used_disk_storage")).to eq(1024)
      end
    end
  end
end
