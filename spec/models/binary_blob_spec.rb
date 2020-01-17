# encoding: utf-8

RSpec.describe BinaryBlob do
  context "#binary= and #binary" do
    before { @blob = FactoryBot.build(:binary_blob, :name => "test") }

    subject do
      @blob.binary = @data.dup # binary= is destructive (it changes the object passed to it)
      @blob.save
      @blob.reload
      @blob.binary
    end

    it "without UTF-8 data" do
      @data = "--- Quota - Max CPUs\n...\n"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it "with UTF-8 data with bad encoding" do
      @data = "%PDF-1.4\n%\xE2"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it '#binary= with less data than the max parts size' do
      data = "test log data"
      @blob.binary = data.dup # binary= destroys the source data, so dup it
      expect(@blob.binary.length).to eq(data.length)
    end

    it '#binary= with more data than the max parts size' do
      data = "test log data"
      data *= ((BinaryBlobPart.default_part_size) / data.length * 2)
      @blob.binary = data.dup # binary= destroys the source data, so dup it
      expect(@blob.binary.length).to eq(data.length)
    end

    it '#binary will handle data that is only made up of hex digits' do
      data = "1234567890abcdef"
      @blob.binary = data.dup # binary= destroys the source data, so dup it
      expect(@blob.binary.length).to eq(data.length)
    end
  end

  context "#dump_binary" do
    before { @blob = FactoryBot.build(:binary_blob, :name => "test") }

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
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it "with UTF-8 data with bad encoding" do
      @data = "%PDF-1.4\n%\xE2"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end
  end

  describe "serializing and deserializing data" do
    it "can store and load data as YAML" do
      bb = FactoryBot.build(:binary_blob)
      data = "foo"

      bb.store_data("YAML", data)

      expect(bb.data).to eq(data)
    end

    it "can store and load Marshaled data" do
      bb = FactoryBot.build(:binary_blob)
      data = "foo"

      bb.store_data("Marshal", data)

      expect(bb.data).to eq("foo")
    end
  end

  describe "#serializer" do
    it "returns YAML if the data_type is YAML" do
      bb = FactoryBot.build(:binary_blob, :data_type => "YAML")
      expect(bb.serializer).to be(YAML)
    end

    it "returns Marshal if data_type is not YAML" do
      bb = FactoryBot.build(:binary_blob, :data_type => "unknown")
      expect(bb.serializer).to be(Marshal)
    end
  end
end
