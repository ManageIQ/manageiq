require "spec_helper"
require "rufus-scheduler"

RSpec.describe MiqScheduleWorker::SchedulesBuilder do
  describe "#schedule_every" do
    let(:scheduler) { Rufus::Scheduler.new }
    let(:queue) { double }
    subject { described_class.new(scheduler, queue) }

    it "catches an error on nil first arg" do
      expect($log).to receive(:error).once
      subject.schedule_every(nil) {}
    end

    it "catches an error on 0 first arg" do
      expect($log).to receive(:error).once
      subject.schedule_every(0) {}
    end

    it "works on nil :first_in" do
      expect($log).not_to receive(:error)
      subject.schedule_every(1, :first_in => nil) {}
    end
  end
end
