RSpec.describe MiqReport do
  let(:miq_report) { FactoryBot.create(:miq_report) }

  before do
    EvmSpecHelper.local_miq_server
  end

  describe "#format_column" do
    it "formats resource_type column" do
      expect(miq_report.format_column("resource_type", {"resource_type" => "Vm"}, Time.zone)).to eq("VM and Instance")
    end

    it "formats column with base report Tenant" do
      miq_report.db = "Tenant"
      expect(miq_report.format_column("tenant_quotas.used", {"tenant_quotas.used" => 786, "tenant_quotas.name" => "cpu_allocated"}, Time.zone)).to eq("786 Count")
    end

    it "formats column with format method" do
      expect(miq_report.format_column("name", {"name" => "VM1"}, Time.zone)).to eq("VM1")
    end
  end

  describe "#build_html_col" do
    it "renders html for resource_type column" do
      expect(miq_report.build_html_col([], "resource_type", nil, {"resource_type" => "Vm"}, Time.zone)).to match_array(["<td>", "VM and Instance", "</td>"])
    end

    it "renders html for with base report Tenant" do
      miq_report.db = "Tenant"
      expect(miq_report.build_html_col([], "tenant_quotas.used", nil, {"tenant_quotas.used" => 786, "tenant_quotas.name" => "cpu_allocated"}, Time.zone)).to match_array(["<td style=\"text-align:right\">", "786 Count", "</td>"])
    end

    it "renders html for string column" do
      expect(miq_report.build_html_col([], "name", nil, {"name" => "VM1"}, Time.zone)).to match_array(["<td>", "VM1", "</td>"])
    end

    it "renders html for time column" do
      string_time_now = "02/15/19 14:32:23 UTC"
      time_now = Time.zone.parse(string_time_now).utc
      expect(miq_report.build_html_col([], "time", nil, {"time" => time_now}, Time.zone)).to match_array(["<td style=\"text-align:center\">", string_time_now, "</td>"])
    end

    it "renders html for integer and float column" do
      expect(miq_report.build_html_col([], "cpus", nil, {"cpus" => 10}, Time.zone)).to match_array(["<td style=\"text-align:right\">", "10", "</td>"])
      expect(miq_report.build_html_col([], "average_speed", nil, {"average_speed" => 20.44}, Time.zone)).to match_array(["<td style=\"text-align:right\">", "20.44", "</td>"])
    end
  end
end
