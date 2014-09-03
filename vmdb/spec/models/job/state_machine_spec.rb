require "spec_helper"

describe Job::StateMachine do
  before do
    module TestStateMachine
      def load_transitions
        self.state ||= 'initialize'
        {
          :initializing => {'initialize' => 'waiting'  },
          :start        => {'waiting'    => 'doing'    ,
                            'retrying'   => 'working'  },
          :cancel       => {'*'          => 'canceling'},
          :stop         => {'*'          => 'stopping' },
          :error        => {'*'          => '*'        }
        }
      end
    end

    class TestJob < Job
      include TestStateMachine
    end

    @obj = TestJob.new
  end

  after do
    Object.send(:remove_const, :TestStateMachine)
    Object.send(:remove_const, :TestJob)
  end

  it "should transition from one state to another by a signal" do
    @obj.signal(:initializing)
    @obj.state.should eq 'waiting'
  end

  it "should transition to another by a signal according to its current state" do
    @obj.state = 'waiting'
    @obj.signal(:start)
    @obj.state.should eq 'doing'

    @obj.state = 'retrying'
    @obj.signal(:start)
    @obj.state.should eq 'working'
  end

  it "should transition to some selected state from any state" do
    @obj.signal(:cancel)
    @obj.state.should eq 'canceling'
  end

  it "should leave the state unchanged for some selected signal" do
    @obj.state = 'doing'
    @obj.signal(:error)
    @obj.state.should eq 'doing'
  end

  it "should raise an error if the transition is not allowed" do
    @obj.state = 'working'
    expect { @obj.signal(:initializing) }.to raise_error
  end

  it "should raise an error if the signal is not defined" do
    @obj.state = 'working'
    expect { @obj.signal(:wrong) }.to raise_error
  end
end
