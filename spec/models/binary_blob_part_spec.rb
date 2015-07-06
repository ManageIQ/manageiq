# encoding: utf-8

require "spec_helper"

describe BinaryBlobPart do
  context "#data= and #data" do
    before(:each) do
      @part = FactoryGirl.create(:binary_blob_part)
    end

    subject do
      @part.data = @data
      @part.save
      @part.reload
      @part.data
    end

    it "without UTF-8 data" do
      @data = "--- Quota - Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end
  end
end
