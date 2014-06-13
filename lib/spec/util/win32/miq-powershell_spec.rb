require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util win32})))
require 'miq-powershell'

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
    hash[:ps_time][:DT].should == Time.parse("2012-12-10T14:44:07.0033672-06:00")
    hash[:ps_time][:DT].utc?.should == false

    # Time value contains timezone offset (UTC)
    hash[:ps_time_utc].should == Time.parse("2012-12-10T20:44:07.0033672Z")
    hash[:ps_time_utc].utc?.should == true

    # Time value does not contain timezone (Treat as UTC)
    hash[:xen_desktop_time].should == Time.parse("2012-12-10T20:43:29.649091Z")
    hash[:xen_desktop_time].utc?.should == true
  end
end
