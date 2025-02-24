RSpec.describe MiqWebServerWorkerMixin do
  it "build_uri (ipv6)" do
    test_class = Class.new do
      include MiqWebServerWorkerMixin
    end

    allow(test_class).to receive_messages(:binding_address => "::1")
    expect(test_class.build_uri(123)).to eq "http://[::1]:123"
  end

  let(:test_class) do
    Class.new do
      include MiqWebServerWorkerMixin
    end
  end

  it "#rails_server_options" do
    w = FactoryBot.create(:miq_ui_worker, :uri => "http://127.0.0.1:3000")
    expect(w.rails_server_options).to include(
      :Port        => 3000,
      :Host        => w.class.binding_address,
      :environment => Rails.env.to_s,
      :app         => Rails.application
    )
  end

  it "overloading and calling super on a class method" do
    before = test_class.binding_address

    test_class.class_eval do
      def self.binding_address
        super + "JUNK"
      end
    end

    expect(test_class.binding_address).to eq(before + "JUNK")
  end

  describe '#rails_application' do
    let(:remote_console_worker) { FactoryBot.create(:miq_remote_console_worker, :uri => 'http://127.0.0.1:3000') }
    let(:ui_worker) { FactoryBot.create(:miq_ui_worker, :uri => 'http://127.0.0.1:3000') }

    it 'provides access to the Rack/Rails application' do
      expect(remote_console_worker.rails_application).to be_a_kind_of(RemoteConsole::RackServer)
      expect(ui_worker.rails_application).to be_a_kind_of(Vmdb::Application)
    end
  end
end
