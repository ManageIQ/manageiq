require 'util/vmdb-logger'

describe VMDBLogger do
  describe "#log_hashes" do
    let(:buffer) { StringIO.new }
    let(:logger) { described_class.new(buffer) }

    it "filters out passwords when keys are symbols" do
      hash = {:a => {:b => 1, :password => "pa$$w0rd"}}
      logger.log_hashes(hash)

      buffer.rewind
      expect(buffer.read).to_not include("pa$$w0rd")
    end

    it "filters out passwords when keys are strings" do
      hash = {"a" => {"b" => 1, "password" => "pa$$w0rd"}}
      logger.log_hashes(hash)

      buffer.rewind
      expect(buffer.read).to_not include("pa$$w0rd")
    end

    it "with :filter option, filters out given keys and passwords" do
      hash = {:a => {:b => 1, :extra_key => "pa$$w0rd", :password => "pa$$w0rd"}}
      logger.log_hashes(hash, :filter => :extra_key)

      buffer.rewind
      expect(buffer.read).to_not include("pa$$w0rd")
    end
  end

  it ".contents with no log returns empty string" do
    allow(File).to receive_messages(:file? => false)
    expect(VMDBLogger.contents("mylog.log")).to eq("")
  end

  it ".contents with empty log returns empty string" do
    require 'util/miq-system'
    allow(MiqSystem).to receive_messages(:tail => "")

    allow(File).to receive_messages(:file? => true)
    expect(VMDBLogger.contents("mylog.log")).to eq("")
  end

  context "with evm log snippet with invalid utf8 byte sequence data" do
    before(:each) do
      @log = File.expand_path(File.join(File.dirname(__FILE__), "data/redundant_utf8_byte_sequence.log"))
    end

    context "accessing the invalid data directly" do
      before(:each) do
        @data = File.read(@log)
      end

      it "should have content with the invalid utf8 lines" do
        expect(@data).not_to be_nil
        expect(@data.kind_of?(String)).to be_truthy
      end

      it "should unpack raw data as UTF-8 characters and raise ArgumentError" do
        expect { @data.unpack("U*") }.to raise_error(ArgumentError)
      end
    end

    context "using VMDBLogger with no width" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(nil, 1000)
      end

      it "should have content but without the invalid utf8 lines" do
        expect(@contents).not_to be_nil
        expect(@contents.kind_of?(String)).to be_truthy
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        expect { @contents.unpack("U*") }.not_to raise_error
      end
    end

    context "using VMDBLogger with a provided width" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(120, 5000)
      end

      it "should have content but without the invalid utf8 lines" do
        expect(@contents).not_to be_nil
        expect(@contents.kind_of?(String)).to be_truthy
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        expect { @contents.unpack("U*") }.not_to raise_error
      end
    end

    context "using VMDBLogger no limit on lines read" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(120, nil)
      end

      it "should have content but without the invalid utf8 lines" do
        expect(@contents).not_to be_nil
        expect(@contents.kind_of?(String)).to be_truthy
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        expect { @contents.unpack("U*") }.not_to raise_error
      end
    end

    context "encoding" do
      it "with ascii file" do
        log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log"))
        expect(VMDBLogger.new(log).contents.encoding.name).to eq("UTF-8")
        expect(VMDBLogger.new(log).contents(100, nil).encoding.name).to eq("UTF-8")
      end

      it "with utf-8 file" do
        log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_utf8.log"))
        expect(VMDBLogger.new(log).contents.encoding.name).to eq("UTF-8")
        expect(VMDBLogger.new(log).contents(100, nil).encoding.name).to eq("UTF-8")
      end
    end
  end
end
