require "spec_helper"

describe "Service Retirement Management" do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)
  end

  it "#retirement_check" do
    service = FactoryGirl.create(:service)
    MiqEvent.should_receive(:raise_evm_event)
    service.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    service.retirement_last_warn.should be_nil
    service.class.any_instance.should_receive(:retire_now).once
    Service.retirement_check
    service.reload
    service.retirement_last_warn.should_not be_nil
    (Time.now.utc - service.retirement_last_warn).should be < 30
  end

  it "#retirement_due?" do
    service = FactoryGirl.create(:service)
    service.retirement_due?.should be_false

    service.retires_on = Date.today + 1.day
    service.save!
    service.retirement_due?.should be_false

    service.retires_on = Date.today
    service.save!
    service.retirement_due?.should be_true

    service.retires_on = Date.today - 1.day
    service.save!
    service.retirement_due?.should be_true
  end
end
