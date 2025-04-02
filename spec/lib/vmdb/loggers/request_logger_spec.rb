RSpec.describe Vmdb::Loggers::RequestLogger do
  let(:object_id) { 10 }
  let(:log_stream) { double }
  let(:log) { described_class.new(object_id, logger: log_stream) }

  let(:message) { "stuff happened" }

  it "logs to output" do
    expect(log_stream).to receive(:info?).and_return(true)
    expect(log_stream).to receive(:info).with(message)
    log.info(message)
  end

  it "creates a record" do
    expect(log_stream).to receive(:info?).and_return(true)
    expect(log_stream).to receive(:info).with(message)

    log.info(message)
    request_log = RequestLog.last
    expect(request_log.severity).to eq("INFO")
    expect(request_log.message).to eq(message)
  end

  it "doesn't log when the level is too low" do
    expect(log_stream).to receive(:debug?).and_return(false)
    expect(log_stream).not_to receive(:debug)

    log.debug(message)

    expect(RequestLog.exists?).to be(false)
  end
end
