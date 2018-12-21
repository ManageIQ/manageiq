describe RequestStartedOnMiddleware do
  context ".long_running_requests" do
    before do
      allow(described_class).to receive(:relevant_thread_list) { fake_threads }
      allow(described_class).to receive(:request_timeout).and_return(2.minutes)
    end

    let(:fake_threads) { [@fake_thread] }

    it "returns request, duration and thread" do
      @fake_thread = {:current_request => "/api/ping", :current_request_started_on => 3.minutes.ago}
      long_requests = described_class.long_running_requests.first
      expect(long_requests[0]).to eql "/api/ping"
      expect(long_requests[1]).to be_within(0.1).of(Time.now.utc - 3.minutes.ago)
      expect(long_requests[2]).to eql @fake_thread
    end

    it "skips threads that haven't timed out yet" do
      @fake_thread = {:current_request => "/api/ping", :current_request_started_on => 30.seconds.ago}
      expect(described_class.long_running_requests).to be_empty
    end

    it "skips threads with no requests" do
      @fake_thread = {}
      expect(described_class.long_running_requests).to be_empty
    end
  end
end
