# encoding: utf-8

require "spec_helper"

describe BinaryBlob do
  before(:each) do
    @blob = FactoryGirl.create(:binary_blob, :name => "test")
  end

  context "#binary= and #binary" do
    subject do
      @blob.binary = @data.dup # binary= is descructive (it changes the object passed to it)
      @blob.save
      @blob.reload
      @blob.binary
    end

    it "without UTF-8 data" do
      @data = "--- Quota - Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

    it "with UTF-8 data with bad encoding" do
      @data = "%PDF-1.4\n%\xE2"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end
  end

  context "#dump_binary" do
    subject do
      @blob.binary = @data.dup
      @string = StringIO.new
      @blob.save
      @blob.reload
      @blob.dump_binary(@string)
      @string.rewind
      @string.read
    end

    it "without UTF-8 data" do
      @data = "--- Quota - Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

    it "with UTF-8 data with bad encoding" do
      @data = "%PDF-1.4\n%\xE2"
      subject.bytes.to_a.should == @data.bytes.to_a
    end

  end

  it '#binary= with less data than the max parts size' do
    data = "test log data"
    @blob.binary = data.dup # binary= destroys the source data, so dup it
    @blob.binary.length.should == data.length
  end

  it '#binary= with more data than the max parts size' do
    data = "test log data"
    data = data * ((BinaryBlobPart.default_part_size) / data.length * 2)
    @blob.binary = data.dup # binary= destroys the source data, so dup it
    @blob.binary.length.should == data.length
  end

  it '#binary will handle data that is only made up of hex digits' do
    data = "1234567890abcdef"
    @blob.binary = data.dup # binary= destroys the source data, so dup it
    @blob.binary.length.should == data.length
  end
end
