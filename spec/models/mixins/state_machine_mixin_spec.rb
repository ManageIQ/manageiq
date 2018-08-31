describe StateMachineMixin do
  let(:job_class) do
    Class.new do
      attr_accessor :state
      include StateMachineMixin

      def transitions
        {
          :initializing => {'waiting_to_start' => 'waiting'},
          :start        => {'waiting'  => 'doing',
                            'retrying' => 'working'},
          :cancel       => {'*'                => 'canceling'},
          :stop         => {'*'                => 'stopping'},
          :error        => {'*'                => '*'}
        }
      end
    end
  end

  let(:job) { job_class.new }

  before do
    allow(job).to receive(:save)
    allow(job).to receive(:cancel)
  end

  it "should transition from one state to another by a signal" do
    job.state = "waiting_to_start"
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
    expect(job.state).to eq '*'
  end

  it "should raise an error if the transition is not allowed" do
    job.state = 'working'
    expect { job.signal(:initializing) }
      .to raise_error(RuntimeError, "initializing is not permitted at state working")
  end

  it "should raise an error if the signal is not defined" do
    job.state = 'working'
    expect { job.signal(:wrong) }.to raise_error(RuntimeError, "wrong is not permitted at state working")
  end
end
