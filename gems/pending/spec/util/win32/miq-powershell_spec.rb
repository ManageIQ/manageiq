require "spec_helper"
require 'util/win32/miq-powershell'
require 'time'

describe MiqPowerShell do
  MIQ_POWER_SHELL_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

  before(:each) do
    @xml_data = File.read(File.join(MIQ_POWER_SHELL_DATA_DIR, "ps_dates.xml"))
  end

  it "Convert" do
    ps = MiqPowerShell::Convert.new(@xml_data)
    ps_array = ps.to_h
    hash = ps_array.first

    # Time value contains timezone offset (localtime)
    expect(hash[:ps_time][:DT]).to eq(Time.parse("2012-12-10T14:44:07.0033672-06:00"))
    expect(hash[:ps_time][:DT].utc?).to eq(false)

    # Time value contains timezone offset (UTC)
    expect(hash[:ps_time_utc]).to eq(Time.parse("2012-12-10T20:44:07.0033672Z"))
    expect(hash[:ps_time_utc].utc?).to eq(true)

    # Time value does not contain timezone (Treat as UTC)
    expect(hash[:xen_desktop_time]).to eq(Time.parse("2012-12-10T20:43:29.649091Z"))
    expect(hash[:xen_desktop_time].utc?).to eq(true)
  end
end
