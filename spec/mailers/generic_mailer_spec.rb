describe GenericMailer do
  before do
    @miq_server = EvmSpecHelper.local_miq_server
    @args = {
      :to      => "you@bedrock.gov",
      :from    => "me@bedrock.gov",
      :subject => "GenericMailerTests",
      :body    => "testing123"
    }
    ActionMailer::Base.deliveries.clear
  end

  context 'with a notifier within a region' do
    before do
      MiqRegion.seed
      ServerRole.seed
      @miq_server.server_roles << ServerRole.where(:name => 'notifier')
      @miq_server.save!
    end

    it "call deliver_queue for generic_notification" do
      @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_mailer_test.txt", :body => "generic_notification with text/plain attachment" * 10}]
      expect(BinaryBlob.count).to eq(0)
      GenericMailer.deliver_queue(:generic_notification, @args)
      expect(BinaryBlob.count).to eq(1)
      expect(MiqQueue.exists?(:method_name => 'deliver',
                              :class_name  => described_class.name,
                              :role        => 'notifier')).to be_truthy
    end

    it "call deliver_queue for automation_notification" do
      GenericMailer.deliver_queue(:automation_notification, @args)
      expect(MiqQueue.exists?(:method_name => 'deliver',
                              :class_name  => described_class.name,
                              :role        => 'notifier')).to be_truthy
    end
  end

  context 'without a notifier within a region' do
    before { MiqRegion.seed }

    it 'does not queue any mail notifications' do
      @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_mailer_test.txt", :body => "generic_notification with text/plain attachment" * 10}]
      expect { GenericMailer.deliver_queue(:generic_notification, @args) }.not_to(change { MiqQueue.count })
    end
  end

  context "delivery error" do
    it "call attempts to send message to recipients indivually" do
      # generate message w/ two recipients that
      # raises error when delivered
      msg = @args.merge(:to => 'me@bedrock.gov, you@bedrock.gov')
      notification = GenericMailer.generic_notification(msg)
      allow(notification).to receive(:deliver_now).and_raise(Net::SMTPFatalError)

      # send error msg first...
      expect(GenericMailer)
        .to receive(:generic_notification)
        .and_return(notification)

      # ...after delegate to normal behaviour
      expect(GenericMailer)
        .to receive(:generic_notification)
        .twice
        .and_call_original

      # send message
      GenericMailer.deliver(:generic_notification)

      # ensure individual messages were sent
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(ActionMailer::Base.deliveries.first.to).to eq(['me@bedrock.gov'])
      expect(ActionMailer::Base.deliveries.last.to).to eq(['you@bedrock.gov'])
    end
  end

  context "connection error" do
    it "returns gracefully" do
      # generate message that will raise connection error when delivered
      notification = GenericMailer.generic_notification(@args)
      allow(notification).to receive(:deliver_now).and_raise(Errno::ECONNREFUSED)

      # generate error message on request
      expect(GenericMailer)
        .to receive(:generic_notification)
        .and_return(notification)

      # send message
      expect do
        GenericMailer.deliver(:generic_notification)
      end.not_to raise_error
    end
  end

  it "call deliver for generic_notification" do
    msg = GenericMailer.deliver(:generic_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
  end

  it "call deliver for generic_notification without a 'from' address" do
    stub_settings(:smtp => {:from => "test@123.com"})
    new_args = @args.dup
    new_args.delete(:from)
    msg = GenericMailer.deliver(:generic_notification, new_args)
    expect(msg.from).to eq(["test@123.com"])
  end

  it "call deliver for automation_notification" do
    msg = GenericMailer.deliver(:automation_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
  end

  it "call deliver for automation_notification with attachment as BinaryBlob" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "generic_mailer_test.txt", :body => "automation_notification with attachment" * 2}]
    expect(BinaryBlob.count).to eq(0)
    @args[:attachment] = GenericMailer.attachment_to_blob(@args[:attachment])
    expect(BinaryBlob.count).to eq(1)
    msg = GenericMailer.deliver(:automation_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
    expect(BinaryBlob.count).to eq(0)
  end

  it "call deliver for automation_notification, with attachment as BinaryBlob, and generate filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => nil, :body => "automation_notification with attachment" * 2}]
    expect(BinaryBlob.count).to eq(0)
    @args[:attachment] = GenericMailer.attachment_to_blob(@args[:attachment])
    expect(BinaryBlob.count).to eq(1)
    msg = GenericMailer.deliver(:automation_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
    expect(BinaryBlob.count).to eq(0)
  end

  it "call blob_to_attachment and attachment_to_blob" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "generic_mailer_test.txt", :body => "maryhadalittlelamb" * 10}]
    expect(BinaryBlob.count).to eq(0)
    GenericMailer.attachment_to_blob(@args[:attachment])
    expect(BinaryBlob.count).to eq(1)
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    expect(btoa_attachment[0][:filename]).to eq("generic_mailer_test.txt")
    expect(@args[:attachment][0][:body].length).to eq(btoa_attachment[0][:body].length)
    expect(BinaryBlob.count).to eq(0)
  end

  it "call blob_to_attachment and attachment_to_blob and generate attachment filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => nil, :body => "maryhadalittlelamb" * 10},
                          {:content_type => "application/txt", :filename => nil, :body => "itsfleecewaswhiteassnow" * 10}]
    expect(@args[:attachment][0][:filename]).to be_nil
    expect(BinaryBlob.count).to eq(0)
    GenericMailer.attachment_to_blob(@args[:attachment])
    expect(BinaryBlob.count).to eq(2)
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    expect(btoa_attachment[0][:filename]).to eq("evm_attachment_1")
    expect(btoa_attachment[1][:filename]).to eq("evm_attachment_2")
    expect(@args[:attachment][0][:body].length).to eq(btoa_attachment[0][:body].length)
    expect(BinaryBlob.count).to eq(0)
  end

  it "call blob_to_attachment and attachment_to_blob and do not generate attachment filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "maryhadalittlelamb.txt", :body => "maryhadalittlelamb" * 10},
                          {:content_type => "application/txt", :filename => "itsfleecewaswhiteassnow.txt", :body => "itsfleecewaswhiteassnow" * 10}]
    expect(BinaryBlob.count).to eq(0)
    GenericMailer.attachment_to_blob(@args[:attachment])
    expect(BinaryBlob.count).to eq(2)
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    expect(btoa_attachment[0][:filename]).to eq("maryhadalittlelamb.txt")
    expect(btoa_attachment[1][:filename]).to eq("itsfleecewaswhiteassnow.txt")
    expect(@args[:attachment][0][:body].length).to eq(btoa_attachment[0][:body].length)
    expect(BinaryBlob.count).to eq(0)
  end

  it "call deliver for generic_notification with text/plain attachment" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_mailer_test.txt", :body => "generic_notification with text/plain attachment" * 10}]
    expect(BinaryBlob.count).to eq(0)
    msg = GenericMailer.deliver(:generic_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
    expect(BinaryBlob.count).to eq(0)
  end

  it "call deliver for generic_notification with text/html attachment" do
    @args[:attachment] = [{:content_type => "text/html", :filename => "generic_mailer_test.txt", :body => "generic_notification" * 10}]
    msg = GenericMailer.deliver(:generic_notification, @args)
    expect(ActionMailer::Base.deliveries).to eq([msg])
  end

  it "call automation_notification directly" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "automation_filename.txt", :body => "automation_notification" * 10}]
    expect(GenericMailer.automation_notification(@args).message).to be_kind_of(Mail::Message)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "call generic_notification directly" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_filename.txt", :body => "generic_notification" * 10}]
    expect(GenericMailer.generic_notification(@args).message).to be_kind_of(Mail::Message)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "policy_action_email" do
    @args[:miq_action_hash] = {
      :header            => "Alert Triggered",
      :policy_detail     => "Alert 'Do something on vm start policy', triggered",
      :event_description => "Vm started event!",
      :entity_type       => "Vm",
      :entity_name       => "My Vm"
    }
    mail = GenericMailer.policy_action_email(@args)
    expect(mail.parts.length).to eq(2)
    expect(mail.mime_type).to eq("multipart/alternative")
    expect(mail.parts[0].mime_type).to eq("text/plain")
    expect(mail.parts[0].body).to match(/Do something on vm start policy/)
    expect(mail.parts[1].mime_type).to eq("text/html")
    expect(mail.parts[1].body).to match(%r{<h3>[\s]*Alert Triggered[\s]*</h3>})
  end

  describe "#test_mail" do
    it "should be called directly" do
      mail = GenericMailer.test_email(@args[:to], {})
      expect(mail.subject).to start_with Vmdb::Appliance.PRODUCT_NAME
    end

    it "should not change the input parameters" do
      settings = {:host => "localhost"}
      GenericMailer.test_email(@args[:to], settings)
      expect(settings[:host]).to eq("localhost")
    end
  end

  it "returns an array of authentication modes" do
    expect(GenericMailer.authentication_modes).to eq([["login", "login"], ["plain", "plain"], ["none", "none"]])
  end

  it "returns an array of openssl verify modes" do
    expect(GenericMailer.openssl_verify_modes).to eq([["None", "none"], ["Peer", "peer"], ["Client Once", "client_once"], ["Fail If No Peer Cert", "fail_if_no_peer_cert"]])
  end

  it "sets optional smtp keys as expected" do
    mail = GenericMailer.new
    options = {:enable_starttls_auto => false, :openssl_verify_mode => :none}
    mail.send(:set_mailer_smtp, options)
    options.delete(:authentication) # Deal with current pass by ref issue
    expect(ActionMailer::Base.smtp_settings).to include(options)
  end
end
