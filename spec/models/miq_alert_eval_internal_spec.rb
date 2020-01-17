RSpec.describe "MiqAlert Evaluation Internal" do
  context "With VM as a target," do
    before do
      @vm = FactoryBot.create(:vm_vmware)
    end

    context "evaluating an event threshold alert" do
      before do
        @events = []
        @events << FactoryBot.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => Time.now.utc)
        @events << FactoryBot.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 1.day.ago.utc)
        @events << FactoryBot.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 2.days.ago.utc)
        @events << FactoryBot.create(:ems_event, :vm_or_template_id => @vm.id, :event_type => "MigrateVM_Task_Complete", :timestamp => 3.days.ago.utc)

        expression = {
          :eval_method => "event_threshold",
          :mode        => "internal",
          :options     => {
            :event_types    => ["MigrateVM_Task_Complete"],
            :freq_threshold => 3,
            :time_threshold => 3.days}}
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_truthy
      end
    end

    context "evaluating a realtime performance alert" do
      before do
        t = 2.minutes.ago.utc
        6.times do |i|
          FactoryBot.create(:metric_vm_rt, :resource_id => @vm.id, :timestamp => t, :mem_vmmemctl_absolute_average => (250 + (i * 10)))
          t += 20.seconds
        end

        expression = {
          :eval_method => "realtime_performance",
          :mode        => "internal",
          :options     => {
            :operator          => ">",
            :perf_column       => "mem_vmmemctl_absolute_average",
            :value_threshold   => "250",
            :rt_time_threshold => 60,
            :trend_direction   => 'none',
            :debug_trace       => 'false'}}
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_truthy
      end
    end

    context "evaluating a changed vm value alert" do
      before do
        # TODO: create drift for test
        expression = {
          :eval_method => "changed_vm_value",
          :mode        => "internal",
          :options     => {
            :operator => "Changed",
            :hdw_attr => :cpu_affinity}}
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_falsey
      end
    end

    context "evaluating a reconfigured hardware value alert" do
      before do
        # TODO: create drift for test
        expression = {
          :eval_method => "reconfigured_hardware_value",
          :mode        => "internal",
          :options     => {
            :operator => "Decreased",
            :hdw_attr => "memory_mb"}}
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_falsey
      end
    end

    context "evaluating a VM event log threshold alert" do
      before do
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
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to false" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_falsey
      end
    end

    context "evaluating a VM Alarm alert" do
      before do
        expression = {
          :eval_method => "ems_alarm",
          :mode        => "internal",
          :options     => {
            :ems_id         => 1,
            :ems_alarm_name => "GT VM CPU Usage",
            :ems_alarm_mor  => "alarm-7"
          }}
        @alert      = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_vm)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@vm)
      end

      it "should result to true" do
        expect { @result = @alert.evaluate(@vm) }.not_to raise_error
        expect(@result).to be_truthy
      end
    end
  end

  context "With Host as a target," do
    before do
      @host = FactoryBot.create(:host)
    end

    context "evaluating a hostd log threshold alert" do
      before do
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
        @alert = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set_host)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@host)
      end

      it "should result to false" do
        expect { @result = @alert.evaluate(@host) }.not_to raise_error
        expect(@result).to be_falsey
      end
    end
  end

  context "With MiqServer as a target," do
    before do
      @server = FactoryBot.create(:miq_server, :zone => FactoryBot.create(:zone))
    end

    context "evaluating an alert with no expression" do
      before do
        expression = {:eval_method => "nothing"}
        @alert = FactoryBot.create(:miq_alert_vm, :expression => expression)
        @alert_prof = FactoryBot.create(:miq_alert_set, :mode => @server.class.name)
        @alert_prof.add_member(@alert)
        @alert_prof.assign_to_objects(@server)
      end

      it "should result to true" do
        expect { @result = @alert.evaluate(@server) }.not_to raise_error
        expect(@result).to be_truthy
      end
    end
  end
end
