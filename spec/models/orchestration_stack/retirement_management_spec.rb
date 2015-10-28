require "spec_helper"

describe "Service Retirement Management" do
  before(:each) do
    @miq_server = EvmSpecHelper.local_miq_server
    @stack = FactoryGirl.create(:orchestration_stack)
  end

  it "#retirement_check" do
    MiqEvent.should_receive(:raise_evm_event)
    @stack.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    expect(@stack.retirement_last_warn).to be_nil
    @stack.class.any_instance.should_receive(:retire_now).once
    @stack.retirement_check
    @stack.reload
    expect(@stack.retirement_last_warn).not_to be_nil
    expect(Time.now.utc - @stack.retirement_last_warn).to be < 30
  end

  it "#start_retirement" do
    expect(@stack.retirement_state).to be_nil
    @stack.start_retirement
    @stack.reload
    expect(@stack.retirement_state).to eq("retiring")
  end

  it "#retire_now" do
    expect(@stack.retirement_state).to be_nil
    expect(MiqEvent).to receive(:raise_evm_event).once
    @stack.retire_now
    @stack.reload
  end

  it "#retire_now with userid" do
    expect(@stack.retirement_state).to be_nil
    event_name = 'request_orchestration_stack_retire'
    event_hash = {:orchestration_stack => @stack, :type => "OrchestrationStack",
                  :retirement_initiator => "user", :user_id => "freddy"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash).once

    @stack.retire_now('freddy')
    @stack.reload
  end

  it "#retire_now without userid" do
    expect(@stack.retirement_state).to be_nil
    event_name = 'request_orchestration_stack_retire'
    event_hash = {:orchestration_stack => @stack, :type => "OrchestrationStack",
                  :retirement_initiator => "system"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash).once

    @stack.retire_now
    @stack.reload
  end

  it "#retire warn" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:warn] = 2.days.to_i
    @stack.retire(options)
    @stack.reload
    expect(@stack.retirement_warn).to eq(options[:warn])
  end

  it "#retire date" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:date] = Date.today
    @stack.retire(options)
    @stack.reload
    expect(@stack.retires_on).to eq(options[:date])
  end

  it "#finish_retirement" do
    expect(@stack.retirement_state).to be_nil
    @stack.finish_retirement
    @stack.reload
    expect(@stack.retired).to be_true
    expect(@stack.retires_on).to eq(Date.today)
    expect(@stack.retirement_state).to eq("retired")
  end

  it "#retiring - false" do
    expect(@stack.retirement_state).to be_nil
    expect(@stack.retiring?).to be_false
  end

  it "#retiring - true" do
    @stack.update_attributes(:retirement_state => 'retiring')
    expect(@stack.retiring?).to be_true
  end

  it "#error_retiring - false" do
    expect(@stack.retirement_state).to be_nil
    expect(@stack.error_retiring?).to be_false
  end

  it "#error_retiring - true" do
    @stack.update_attributes(:retirement_state => 'error')
    expect(@stack.error_retiring?).to be_true
  end

  it "#retires_on - today" do
    expect(@stack.retirement_due?).to be_false
    @stack.retires_on = Date.today
    expect(@stack.retirement_due?).to be_true
  end

  it "#retires_on - tomorrow" do
    expect(@stack.retirement_due?).to be_false
    @stack.retires_on = Date.today + 1
    expect(@stack.retirement_due?).to be_false
  end

  it "#retirement_due?" do
    expect(@stack.retirement_due?).to be_false

    @stack.update_attributes(:retires_on => Date.today + 1.day)
    expect(@stack.retirement_due?).to be_false

    @stack.update_attributes(:retires_on => Date.today)
    expect(@stack.retirement_due?).to be_true

    @stack.update_attributes(:retires_on => Date.today - 1.day)
    expect(@stack.retirement_due?).to be_true
  end

  it "#raise_retirement_event" do
    event_name = 'foo'
    event_hash = {
      :orchestration_stack  => @stack,
      :type                 => "OrchestrationStack",
      :retirement_initiator => "system"
    }
    expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash)
    @stack.raise_retirement_event(event_name)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    event_hash = {
      :target_class => "OrchestrationStack",
      :target_id    => @stack.id.to_s,
      :event        => event_name,
      :message      => message
    }
    expect(AuditEvent).to receive(:success).with(event_hash)
    @stack.raise_audit_event(event_name, message)
  end
end
