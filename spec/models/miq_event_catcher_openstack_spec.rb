require "spec_helper"

describe MiqEventCatcherOpenstack do
  before do
    @ems = FactoryGirl.create(:ems_openstack)
    @ems.stub(:authentication_status_ok?).and_return(true)
    MiqEventCatcherOpenstack.stub(:all_ems_in_zone).and_return([@ems])
  end

  it "logs info about EMS that do not have Event Monitors available" do
    @ems.stub(:event_monitor_available?).and_return(false)
    $log.should_receive(:info).with(/Event Monitor unavailable for #{@ems.name}/)
    MiqEventCatcherOpenstack.all_valid_ems_in_zone.should_not include @ems
  end

  it "does not log info about unavailable Event Monitors when EMS can provide an event monitor" do
    @ems.stub(:event_monitor_available?).and_return(true)
    $log.should_not_receive(:info).with(/Event Monitor unavailable for #{@ems.name}/)
    MiqEventCatcherOpenstack.all_valid_ems_in_zone.should include @ems
  end
end
