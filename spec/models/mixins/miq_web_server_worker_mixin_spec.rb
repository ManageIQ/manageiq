describe MiqWebServerWorkerMixin do
  it "build_uri (ipv6)" do
    test_class = Class.new do
      include MiqWebServerWorkerMixin
    end

    allow(test_class).to receive_messages(:binding_address => "::1")
    expect(test_class.build_uri(123)).to eq "http://[::1]:123"
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
end
