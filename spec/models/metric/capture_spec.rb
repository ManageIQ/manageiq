require "spec_helper"

describe Metric::Capture do
  context ".capture_threshold" do
    before do
      @capture    = 20
      @capture_rt = 2
      settings =  {:performance =>
                    {:capture_threshold             => {:vm => @capture,    :host => @capture},
                     :capture_threshold_with_alerts => {:vm => @capture_rt, :host => @capture_rt}
                    }
                  }
      VMDB::Config.any_instance.stub(:config).and_return(settings)
      @time = Time.utc(2013, 4, 22, 8, 31)
    end

    it "realtime vm uses capture_threshold_with_alerts minutes ago" do
      @target = FactoryGirl.build(:vm_vmware)
      MiqAlert.stub(:target_needs_realtime_capture?).with(@target).and_return(true)

      Timecop.freeze(@time) do
        Metric::Capture.capture_threshold(@target).should == @capture_rt.minutes.ago.utc
      end
    end

    it "realtime host uses capture_threshold_with_alerts minutes ago" do
      @target = FactoryGirl.build(:host_vmware)
      MiqAlert.stub(:target_needs_realtime_capture?).with(@target).and_return(true)

      Timecop.freeze(@time) do
        Metric::Capture.capture_threshold(@target).should == @capture_rt.minutes.ago.utc
      end
    end

    it "non-realtime vm uses capture_threshold minutes ago" do
      @target = FactoryGirl.build(:vm_vmware)
      MiqAlert.stub(:target_needs_realtime_capture?).with(@target).and_return(false)

      Timecop.freeze(@time) do
        Metric::Capture.capture_threshold(@target).should == @capture.minutes.ago.utc
      end
    end

    it "non-realtime host uses capture_threshold minutes ago" do
      @target = FactoryGirl.build(:host_vmware)
      MiqAlert.stub(:target_needs_realtime_capture?).with(@target).and_return(false)

      Timecop.freeze(@time) do
        Metric::Capture.capture_threshold(@target).should == @capture.minutes.ago.utc
      end
    end
  end
end
