describe Job::StateMachine do
  before do
    module TestStateMachine
      def load_transitions
        self.state ||= 'initialize'
        {
          :initializing => {'initialize' => 'waiting'},
          :start        => {'waiting'  => 'doing',
                            'retrying' => 'working'},
          :cancel       => {'*'          => 'canceling'},
          :stop         => {'*'          => 'stopping'},
          :error        => {'*'          => '*'}
        }
      end
    end

    @obj = Class.new(Job) do
      include TestStateMachine
    end.new
  end

  after do
    Object.send(:remove_const, :TestStateMachine)
  end

  it "should transition from one state to another by a signal" do
    @obj.signal(:initializing)
    expect(@obj.state).to eq 'waiting'
  end

  it "should transition to another by a signal according to its current state" do
    @obj.state = 'waiting'
    @obj.signal(:start)
    expect(@obj.state).to eq 'doing'

    @obj.state = 'retrying'
    @obj.signal(:start)
    expect(@obj.state).to eq 'working'
  end

  it "should transition to some selected state from any state" do
    @obj.signal(:cancel)
    expect(@obj.state).to eq 'canceling'
  end

  it "should leave the state unchanged for some selected signal" do
    @obj.state = 'doing'
    @obj.signal(:error)
    expect(@obj.state).to eq 'doing'
  end

  it "should raise an error if the transition is not allowed" do
    @obj.state = 'working'
    expect { @obj.signal(:initializing) }
      .to raise_error(RuntimeError, /initializing is not permitted at state working/)
  end

  it "should raise an error if the signal is not defined" do
    @obj.state = 'working'
    expect { @obj.signal(:wrong) }.to raise_error(RuntimeError, /wrong is not permitted at state working/)
  end
end
