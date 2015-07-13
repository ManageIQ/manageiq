require "spec_helper"

describe MiqRequestTask do
  context "::StateMachine" do
    context "#signal" do
      it "will deal with exceptions" do
        task = FactoryGirl.create(:miq_request_task)
        task.stub(:miq_request => double("MiqRequest").as_null_object)
        exception = String.xxx rescue $!
        task.stub(:some_state).and_raise(exception)

        $log.should_receive(:error).with(/#{exception.class.name}/)
        $log.should_receive(:error).with(exception.backtrace.join("\n"))
        task.should_receive(:finish)

        task.signal(:some_state)

        task.status.should == "Error"
      end
    end
  end
end
