describe ManageIQ::Providers::Redhat::InfraManager::DiskAttachmentBuilder do
  context "#disk_format_for" do
    context "when storage type is file system" do
      let(:storage) { FactoryGirl.build(:storage_nfs) }
      it "returns 'raw' format for FS storage type" do
        expect(described_class.disk_format_for(storage, false)).to eq("raw")
      end

      it "returns 'raw' format for thin provisioned" do
        expect(described_class.disk_format_for(storage, true)).to eq("raw")
      end
    end

    context "when storage type is block" do
      let(:storage) { FactoryGirl.build(:storage_block) }

      it "returns 'cow' format for block storage type and thin provisioned" do
        expect(described_class.disk_format_for(storage, true)).to eq("cow")
      end

      it "returns 'raw' format for block storage type and thick provisioned" do
        expect(described_class.disk_format_for(storage, false)).to eq("raw")
      end
    end

    context "when storage type is not file system and not blcok" do
      let(:storage) { FactoryGirl.build(:storage_unknown) }
      it "returns 'raw' format as default" do
        expect(described_class.disk_format_for(storage, false)).to eq("raw")
      end
    end
  end

  context "#disk_attachment" do
    let(:storage) { FactoryGirl.build(:storage_nfs, :ems_ref => "http://example.com/storages/XYZ") }

    it "creates disk attachment" do
      builder = described_class.new(:size_in_mb => 10, :storage => storage, :name => "disk-1",
                                    :thin_provisioned => true, :bootable => true, :active => false, :interface => "IDE")
      expected_disk_attachment = {
        :bootable  => true,
        :interface => "IDE",
        :active    => false,
        :disk      => {
          :name             => "disk-1",
          :provisioned_size => 10 * 1024 * 1024,
          :sparse           => true,
          :format           => "raw",
          :storage_domains  => [:id => "XYZ"]
        }
      }

      expect(builder.disk_attachment).to eq(expected_disk_attachment)
    end
  end

  describe ManageIQ::Providers::Redhat::InfraManager::DiskAttachmentBuilder::BooleanParameter do
    let(:param) { nil }
    subject { described_class.new(param).true? }

    context "param is true" do
      let(:param) { true }

      it { is_expected.to be_truthy }
    end

    context "param is false" do
      let(:param) { false }

      it { is_expected.to be_falsey }
    end

    context "param is 'true'" do
      let(:param) { "true" }

      it { is_expected.to be_truthy }
    end

    context "param is 'false'" do
      let(:param) { "false" }

      it { is_expected.to be_falsey }
    end

    context "param is nil" do
      it { is_expected.to be_falsey }
    end

    context "param is 'invalid'" do
      let(:param) { 'invalid' }

      it { is_expected.to be_falsey }
    end
  end
end
