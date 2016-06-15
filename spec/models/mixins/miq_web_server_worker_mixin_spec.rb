describe MiqWebServerWorkerMixin do
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

  before do
    @token   = Rails.application.config.secret_token
    @secrets = Rails.application.secrets
    MiqDatabase.seed
  end

  after do
    Rails.application.config.secret_token = @token
    Rails.application.secrets = @secrets
  end

  it ".configure_secret_token defaults to MiqDatabase session_secret_token" do
    Rails.application.config.secret_token = nil

    test_class.configure_secret_token
    expect(Rails.application.secrets[:secret_token]).to eq(MiqDatabase.first.session_secret_token)
  end

  it ".configure_secret_token accepts an input token" do
    Rails.application.config.secret_token = nil

    token = SecureRandom.hex(64)
    test_class.configure_secret_token(token)
    expect(Rails.application.secrets[:secret_token]).to eq(token)
  end

  it ".configure_secret_token does not reset secrets when token already configured" do
    Rails.application.config.secret_token = SecureRandom.hex(64)
    Rails.application.secrets = nil
    Rails.application.secrets

    test_class.configure_secret_token
    expect(Rails.application.secrets[:secret_token]).to eq(Rails.application.config.secret_token)
  end

  it "#rails_server_options" do
    w = FactoryGirl.create(:miq_ui_worker, :uri => "http://127.0.0.1:3000")
    expect(w.rails_server_options).to have_attributes(
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
    let(:websocket_worker) { FactoryGirl.create(:miq_websocket_worker, :uri => 'http://127.0.0.1:3000') }
    let(:ui_worker) { FactoryGirl.create(:miq_ui_worker, :uri => 'http://127.0.0.1:3000') }

    it 'provides access to the Rack/Rails application' do
      expect(websocket_worker.rails_application).to be_a_kind_of(WebsocketServer)
      expect(ui_worker.rails_application).to be_a_kind_of(Vmdb::Application)
    end
  end
end
