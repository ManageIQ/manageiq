RSpec.describe LiveMetric do
  let(:raw_conditions) do
    "resource_type = 'VmOrTemplate' and resource_id = 6 " \
    "and timestamp >= '2016-04-03 00:00:00' and timestamp <= '2016-04-05 23:00:00' " \
    "and capture_interval_name = 'daily'"
  end

  let(:conditions) { [raw_conditions] }

  let(:incomplete_raw_conditions) do
    "resource_type = 'VmOrTemplate' " \
    "and timestamp >= '2016-04-03 00:00:00' and timestamp <= '2016-04-05 23:00:00' " \
    "and capture_interval_name = 'daily'"
  end

  let(:incomplete_conditions) { [incomplete_raw_conditions] }

  it "#parse_conditions" do
    parsed = LiveMetric.parse_conditions(raw_conditions)
    expect(parsed.size).to eq(5)
    expect(parsed[0][:column]).to eq("resource_type")
    expect(parsed[0][:op]).to eq("=")
    expect(parsed[0][:value]).to eq("VmOrTemplate")
    expect(parsed[1][:column]).to eq("resource_id")
    expect(parsed[1][:op]).to eq("=")
    expect(parsed[1][:value]).to eq("6")
    expect(parsed[2][:column]).to eq("timestamp")
    expect(parsed[2][:op]).to eq(">=")
    expect(parsed[2][:value]).to eq("2016-04-03 00:00:00")
    expect(parsed[3][:column]).to eq("timestamp")
    expect(parsed[3][:op]).to eq("<=")
    expect(parsed[3][:value]).to eq("2016-04-05 23:00:00")
    expect(parsed[4][:column]).to eq("capture_interval_name")
    expect(parsed[4][:op]).to eq("=")
    expect(parsed[4][:value]).to eq("daily")
  end

  it "#process_conditions" do
    processed = LiveMetric.process_conditions(conditions)
    expect(processed[:resource_type]).to eq("VmOrTemplate")
    expect(processed[:resource_id]).to eq("6")
    expect(processed[:start_time]).to eq(Time.parse("2016-04-03 00:00:00 UTC").utc)
    expect(processed[:end_time]).to eq(Time.parse("2016-04-05 23:00:00 UTC").utc)
    expect(processed[:interval_name]).to eq("daily")
  end

  it "#process_conditions raises error on incomplete conditions" do
    expect do
      LiveMetric.process_conditions(incomplete_conditions)
    end.to raise_error(LiveMetric::LiveMetricError, "LiveMetric expression must contain resource_id condition")
  end
end
