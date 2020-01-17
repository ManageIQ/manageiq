RSpec.describe Vmdb::Loggers::FogLogger do
  before do
    @log_stream = StringIO.new
    @log = described_class.new(@log_stream)
    @log.level = VMDBLogger::DEBUG
  end

  context ".instrument" do
    it "with no block" do
      expect(@log.instrument("excon.request", {})).to be_nil
      @log_stream.rewind
      expect(@log_stream.read).to match(/DEBUG -- : excon.request/)
    end

    it "with a block" do
      expect(@log.instrument("excon.request", {}) { true }).to be_truthy
      @log_stream.rewind
      expect(@log_stream.read).to match(/DEBUG -- : excon.request/)
    end
  end
end
