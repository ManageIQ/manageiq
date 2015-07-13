require "spec_helper"

describe "MiqAlert Evaluation Internal" do
  context "With VM as a target," do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
    end

    context "evaluating an event threshold alert" do
      before(:each) do
        @events = []
        @events << FactoryGirl.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => Time.now.utc)
        @events << FactoryGirl.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 1.day.ago.utc)
        @events << FactoryGirl.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 2.days.ago.utc)
        @events << FactoryGirl.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 3.days.ago.utc)

        expression = {
          :eval_method => "event_threshold",
          :mode        => "internal",
          :options     => {
            :event_types    => ["MigrateVM_Task_Complete"],
            :freq_threshold => 3,
            :time_threshold => 3.days}}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal Event Threshold", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal Event Threshold Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_true
      end
    end

    context "evaluating a realtime performance alert" do
      before(:each) do
        t = 2.minutes.ago.utc
        6.times do |i|
          FactoryGirl.create(:metric_vm_rt, :resource_id => @vm.id, :timestamp => t, :mem_vmmemctl_absolute_average => (250 + (i * 10)))
          t += 20.seconds
        end

        expression = {
          :eval_method => "realtime_performance",
          :mode        => "internal",
          :options     => {
            :operator         => ">",
            :perf_column      => "mem_vmmemctl_absolute_average",
            :value_threshold  => "250",
            :rt_time_threshold=> 60,
            :trend_direction  => 'none',
            :debug_trace      => 'false'}}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal RT Perf", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal RT Perf Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_true
      end
    end

    context "evaluating a changed vm value alert" do
      before(:each) do
        # TODO: create drift for test
        expression = {
          :eval_method => "changed_vm_value",
          :mode        => "internal",
          :options     => {
            :operator  => "Changed",
            :hdw_attr => :cpu_affinity}}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal Changed VM Value", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal Changed VM Value Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_false
      end
    end

    context "evaluating a reconfigured hardware value alert" do
      before(:each) do
        # TODO: create drift for test
        expression = {
          :eval_method => "reconfigured_hardware_value",
          :mode        => "internal",
          :options     => {
            :operator  => "Decreased",
            :hdw_attr  => "memory_cpu"}}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal Reconfigured Hardware Value", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal Reconfigured Hardware Value Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_false
      end
    end

    context "evaluating a VM event log threshold alert" do
      before(:each) do
        # TODO: Create factories with event_logs
        expression = {
          :eval_method => "event_log_threshold",
          :mode        => "internal",
          :options     => {
            :freq_threshold                 => "2",
            :event_log_name                 => "SYSTEM",
            :event_log_source               => "kernel",
            :event_log_message_filter_type  => "STARTS WITH",
            :event_log_message_filter_value => "Error in",
            :event_log_event_id             => "12345",
            :time_threshold                 => 86400,
            :event_log_level                => "fatal"}}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal VM Event Log Threshold", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal VM Event Log Threshold Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_false
      end
    end

    context "evaluating a VM Alarm alert" do
      before(:each) do
        expression = {
          :eval_method => "ems_alarm",
          :mode        => "internal",
          :options     => {
            :ems_id         => 1,
            :ems_alarm_name => "GT VM CPU Usage",
            :ems_alarm_mor  => "alarm-7"
          }}
        @alert      = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal VM Alarm Threshold", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal VM Alarm Threshold Profile", :mode => @vm.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        lambda { @result = @alert.evaluate(@vm) }.should_not raise_error
        @result.should be_true
      end
    end
  end

  context "With Host as a target," do
    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    context "evaluating a hostd log threshold alert" do
      before(:each) do
        # TODO: Create factories with event_logs
        expression = {
          :eval_method => "hostd_log_threshold",
          :mode        => "internal",
          :options     => {
            :freq_threshold                 => "2",
            :event_log_source               => "Memory checker",
            :event_log_message_filter_type  => "INCLUDES",
            :event_log_message_filter_value => "exceeds soft limit",
            :time_threshold                 => 86400,
            :event_log_level                => "warn"}}
        @alert = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal Hostd Log Threshold", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal VM Alarm Threshold Profile", :mode => @host.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@host)
      end

      it "should result to false" do
        lambda { @result = @alert.evaluate(@host) }.should_not raise_error
        @result.should be_false
      end
    end
  end

  context "With MiqServer as a target," do
    before(:each) do
      @server = FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone))
    end

    context "evaluating an alert with no expression" do
      before(:each) do
        expression = {:eval_method => "nothing"}
        @alert = FactoryGirl.create(:miq_alert_vm, :description => "Alert Internal MiqServer with no Expression", :expression => expression)
        @alert_prof = FactoryGirl.create(:miq_alert_set, :description => "Alert Internal MiqServer with no Expression Profile", :mode => @server.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@server)
      end

      it "should result to true" do
        lambda { @result = @alert.evaluate(@server) }.should_not raise_error
        @result.should be_true
      end
    end
  end
end
