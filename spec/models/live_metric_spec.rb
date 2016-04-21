describe LiveMetric do
  context "parse finders methods" do
    it "#resource_type" do
      conditions = "resource_type = 'MiddlewareServer' and resource_id = 6 " \
      "and timestamp >= '2016-04-05 00:00:00' and timestamp <= '2016-04-03 23:00:00' " \
      "and capture_interval_name = 'daily'"
      parsed = LiveMetric.parse_conditions(conditions)
      expect(parsed.size).to eq(5)
      expect(parsed[0][:column]).to eq("resource_type")
      expect(parsed[0][:op]).to eq("=")
      expect(parsed[0][:value]).to eq("MiddlewareServer")
      expect(parsed[1][:column]).to eq("resource_id")
      expect(parsed[1][:op]).to eq("=")
      expect(parsed[1][:value]).to eq("6")
      expect(parsed[2][:column]).to eq("timestamp")
      expect(parsed[2][:op]).to eq(">=")
      expect(parsed[2][:value]).to eq("2016-04-05 00:00:00")
      expect(parsed[3][:column]).to eq("timestamp")
      expect(parsed[3][:op]).to eq("<=")
      expect(parsed[3][:value]).to eq("2016-04-03 23:00:00")
      expect(parsed[4][:column]).to eq("capture_interval_name")
      expect(parsed[4][:op]).to eq("=")
      expect(parsed[4][:value]).to eq("daily")
    end
  end
end
