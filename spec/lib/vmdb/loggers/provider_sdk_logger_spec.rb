RSpec.describe Vmdb::Loggers::ProviderSdkLogger do
  before do
    @log_stream = StringIO.new
    @log = described_class.new(@log_stream)
  end

  it "filters out bearer tokens" do
    @log.log(@log.level, 'Bearer abcd1234 "stuff"')
    @log_stream.rewind
    expect(@log_stream.read).to match(Regexp.quote('Bearer [FILTERED] "stuff"'))
  end

  it "filters out basic tokens" do
    @log.log(@log.level, 'Authorization: "Basic abcd1234"')
    @log_stream.rewind
    expect(@log_stream.read).to match(Regexp.quote('Authorization: "Basic [FILTERED] "'))
  end

  it "filters out sharedkey tokens" do
    @log.log(@log.level, 'SharedKey xxx123 "stuff"')
    @log_stream.rewind
    expect(@log_stream.read).to match(Regexp.quote('SharedKey [FILTERED] "stuff"'))
  end

  it "filters out client secret tokens" do
    @log.log(@log.level, 'client_secret=abc123&management=yadayada')
    @log_stream.rewind
    expect(@log_stream.read).to match(Regexp.quote('client_secret=[FILTERED]&management=yadayada'))
  end
end
