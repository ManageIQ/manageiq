RSpec.describe Vmdb::Loggers::ContainerLogger::Formatter do
  it "logs a message" do
    time = Time.now
    result = described_class.new.call("INFO", time, "some_program", "testing 1, 2, 3")
    expected = {
      "@timestamp" => time.strftime("%Y-%m-%dT%H:%M:%S.%6N "),
      "hostname"   => ENV["HOSTNAME"],
      "level"      => "info",
      "message"    => "testing 1, 2, 3",
      "pid"        => $PROCESS_ID,
      "service"    => "some_program",
      "tid"        => Thread.current.object_id.to_s(16),
    }.delete_nils
    expect(JSON.parse(result)).to eq(expected)
  end

  it "does not escape characters as in ActiveSupport::JSON extensions" do
    time = Time.now
    result = described_class.new.call("INFO", time, "some_program", "xxx < yyy > zzz")
    expect(result).to include('"message":"xxx < yyy > zzz"')
  end
end
