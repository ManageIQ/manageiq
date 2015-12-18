require "spec_helper"

describe PxeImageType do
  context "#esx?" do
    it "with a nil name" do
      expect(subject).not_to be_esx
    end

    it "with a non-esx name" do
      subject.name = 'HyperV'
      expect(subject).not_to be_esx
    end

    it "with a lower case esx name" do
      subject.name = 'esx'
      expect(subject).to be_esx
    end

    it "with an upper case esx name" do
      subject.name = 'ESX'
      expect(subject).to be_esx
    end
  end

  context "duplicated name" do
    it "should raise RecordInvalid error" do
      FactoryGirl.create(:pxe_image_type, :name => "unique_name")
      expect { FactoryGirl.create(:pxe_image_type, :name => "unique_name") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
