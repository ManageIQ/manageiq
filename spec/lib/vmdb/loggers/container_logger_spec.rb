describe Vmdb::Loggers::ContainerLogger::Formatter do
  let(:hostname) { "testhostname" }

  before do
    allow(ENV).to receive(:[]).with('HOSTNAME').and_return(hostname)
  end

  it "stuff" do
    time = Time.now
    result = described_class.new.call("INFO", time, "some_program", "testing 1, 2, 3")
    expect(JSON.parse(result)).to include(
      "@timestamp" => time.strftime("%Y-%m-%dT%H:%M:%S.%6N "),
      "hostname"   => hostname,
      "level"      => "info",
      "message"    => "testing 1, 2, 3",
      "pid"        => $PROCESS_ID,
      "service"    => "some_program",
      "tid"        => Thread.current.object_id.to_s(16),
    )
  end
end
