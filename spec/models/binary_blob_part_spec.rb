# encoding: utf-8

RSpec.describe BinaryBlobPart do
  context "#data= and #data" do
    let(:part) { FactoryBot.build(:binary_blob_part) }

    subject do
      part.data = @data
      part.save
      part.reload
      part.data
    end

    it "without UTF-8 data" do
      @data = "--- Quota - Max CPUs\n...\n"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end

    it "with UTF-8 data" do
      @data = "--- Quota \xE2\x80\x93 Max CPUs\n...\n"
      expect(subject.bytes.to_a).to eq(@data.bytes.to_a)
    end
  end

  it "#inspect has data filtered out" do
    str = "REALLY LONG STRING"
    part = FactoryBot.create(:binary_blob_part, :data => str)
    expect(part.inspect).to_not include(str)

    # Also check for how str is stored as raw binary in the database (as in
    # data_before_type_cast), in case that leaks through to inspect
    expect(part.inspect).to_not include(str.unpack1("H*"))
  end
end
