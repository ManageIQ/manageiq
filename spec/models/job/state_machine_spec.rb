RSpec.describe Job, "::StateMachine" do
  subject(:job) do
    # Job is expected to be subclassed by something
    # that implements load_transitions
    Class.new(described_class) {
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
    }.new
  end

  it "should transition from one state to another by a signal" do
    job.signal(:initializing)
    expect(job.state).to eq 'waiting'
  end

  it "should transition to another by a signal according to its current state" do
    job.state = 'waiting'
    job.signal(:start)
    expect(job.state).to eq 'doing'

    job.state = 'retrying'
    job.signal(:start)
    expect(job.state).to eq 'working'
  end

  it "should transition to some selected state from any state" do
    job.signal(:cancel)
    expect(job.state).to eq 'canceling'
  end

  it "should leave the state unchanged for some selected signal" do
    job.state = 'doing'
    job.signal(:error)
    expect(job.state).to eq 'doing'
  end

  it "should raise an error if the transition is not allowed" do
    job.state = 'working'
    expect { job.signal(:initializing) }
      .to raise_error(RuntimeError, /initializing is not permitted at state working/)
  end

  it "should raise an error if the signal is not defined" do
    job.state = 'working'
    expect { job.signal(:wrong) }.to raise_error(RuntimeError, /wrong is not permitted at state working/)
  end
end
