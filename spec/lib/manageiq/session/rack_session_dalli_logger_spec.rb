describe ManageIQ::Session::RackSessionDalliLogger do
  let(:base_class) do
    Class.new do
      def find_session(_req, sid)
        ["found_#{sid}", {:data => true}]
      end

      def write_session(_req, sid, _data, _env)
        "written_#{sid}"
      end

      def delete_session(_req, sid, _env)
        "deleted_#{sid}"
      end
    end
  end

  let(:logger_class) do
    base_class.dup.tap { |c| c.prepend(described_class) }
  end

  let(:instance) { logger_class.new }
  let(:fake_request) do
    double("ActionDispatch::Request", :request_id => "req-123", :request_method => "GET", :fullpath => "/dashboard/show")
  end

  it "logs and calls super for find_session" do
    expect(Rails.logger).to receive(:debug).with(/RackSessionDalliLogger#find_session.*req-123/)
    result = instance.find_session(fake_request, "sid-1")
    expect(result).to eq(["found_sid-1", {:data => true}])
  end

  it "logs and calls super for write_session" do
    expect(Rails.logger).to receive(:debug).with(/RackSessionDalliLogger#write_session.*req-123/)
    result = instance.write_session(fake_request, "sid-1", {:data => true}, {})
    expect(result).to eq("written_sid-1")
  end

  it "logs and calls super for delete_session" do
    expect(Rails.logger).to receive(:debug).with(/RackSessionDalliLogger#delete_session.*req-123/)
    result = instance.delete_session(fake_request, "sid-1", {})
    expect(result).to eq("deleted_sid-1")
  end
end
