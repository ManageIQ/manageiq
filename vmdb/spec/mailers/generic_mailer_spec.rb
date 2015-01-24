require "spec_helper"

describe GenericMailer do

  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)
    @zone       = FactoryGirl.create(:zone)
    @server_name = "EVM"
    @miq_server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid, :name => @server_name)
    MiqServer.my_server(true)
    @args = {
      :to          => "you@bedrock.gov",
      :from        => "me@bedrock.gov",
      :subject     => "GenericMailerTests",
      :body        => "testing123"
    }
    ActionMailer::Base.deliveries.clear
  end

  it "call deliver_queue for generic_notification" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_mailer_test.txt", :body => "generic_notification with text/plain attachment" * 10}]
    BinaryBlob.count.should == 0
    GenericMailer.deliver_queue(:generic_notification, @args)
    BinaryBlob.count.should == 1
    MiqQueue.exists?(:method_name => 'deliver', :class_name => described_class, :role => 'notifier').should be_true
  end

  it "call deliver_queue for automation_notification" do
    GenericMailer.deliver_queue(:automation_notification, @args)
    MiqQueue.exists?(:method_name => 'deliver', :class_name => described_class, :role => 'notifier').should be_true
  end

  context "delivery error" do
    it "call attempts to send message to recipients indivually" do
      # generate message w/ two recipients that
      # raises error when delivered
      msg = @args.merge({ :to => 'me@bedrock.gov, you@bedrock.gov' })
      notification = GenericMailer.generic_notification(msg)
      notification.stub(:deliver).and_raise(Net::SMTPFatalError)

      # send error msg first...
      GenericMailer.
        should_receive(:generic_notification).
        and_return(notification)

      # ...after delegate to normal behaviour
      GenericMailer.
        should_receive(:generic_notification).
        twice.
        and_call_original

      # send message
      GenericMailer.deliver(:generic_notification)

      # ensure individual messages were sent
      ActionMailer::Base.deliveries.size.should == 2
      ActionMailer::Base.deliveries.first.to.should == ['me@bedrock.gov']
      ActionMailer::Base.deliveries.last.to.should == ['you@bedrock.gov']
    end
  end

  context "connection error" do
    it "returns gracefully" do
      # generate message that will raise connection error when delivered
      notification = GenericMailer.generic_notification(@args)
      notification.stub(:deliver).and_raise(Errno::ECONNREFUSED)

      # generate error message on request
      GenericMailer.
        should_receive(:generic_notification).
        and_return(notification)

      # send message
      lambda{
        GenericMailer.deliver(:generic_notification)
      }.should_not raise_error
    end
  end

  it "call deliver for generic_notification" do
    msg = GenericMailer.deliver(:generic_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
  end

  it "call deliver for generic_notification without a 'from' address" do
    config = VMDB::Config.new("vmdb")
    config.config[:smtp][:from] = "test@123.com"
    VMDB::Config.stub(:new).with("vmdb").and_return(config)
    new_args = @args.dup
    new_args.delete(:from)
    msg = GenericMailer.deliver(:generic_notification, new_args)
    msg.from.should == ["test@123.com"]
  end

  it "call deliver for automation_notification" do
    msg = GenericMailer.deliver(:automation_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
  end

  it "call deliver for automation_notification with attachment as BinaryBlob" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "generic_mailer_test.txt", :body => "automation_notification with attachment" * 2}]
    BinaryBlob.count.should == 0
    @args[:attachment] = GenericMailer.attachment_to_blob(@args[:attachment])
    BinaryBlob.count.should == 1
    msg = GenericMailer.deliver(:automation_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
    BinaryBlob.count.should == 0
  end

  it "call deliver for automation_notification, with attachment as BinaryBlob, and generate filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => nil, :body => "automation_notification with attachment" * 2}]
    BinaryBlob.count.should == 0
    @args[:attachment] = GenericMailer.attachment_to_blob(@args[:attachment])
    BinaryBlob.count.should == 1
    msg = GenericMailer.deliver(:automation_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
    BinaryBlob.count.should == 0
  end

  it "call blob_to_attachment and attachment_to_blob" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "generic_mailer_test.txt", :body => "maryhadalittlelamb" * 10}]
    BinaryBlob.count.should == 0
    atob_attachment = GenericMailer.attachment_to_blob(@args[:attachment])
    BinaryBlob.count.should == 1
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    btoa_attachment[0][:filename].should == "generic_mailer_test.txt"
    @args[:attachment][0][:body].length.should == btoa_attachment[0][:body].length
    BinaryBlob.count.should == 0
  end

  it "call blob_to_attachment and attachment_to_blob and generate attachment filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => nil, :body => "maryhadalittlelamb" * 10},
                          {:content_type => "application/txt", :filename => nil, :body => "itsfleecewaswhiteassnow" * 10}]
    @args[:attachment][0][:filename].should be_nil
    BinaryBlob.count.should == 0
    atob_attachment = GenericMailer.attachment_to_blob(@args[:attachment])
    BinaryBlob.count.should == 2
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    btoa_attachment[0][:filename].should == "evm_attachment_1"
    btoa_attachment[1][:filename].should == "evm_attachment_2"
    @args[:attachment][0][:body].length.should == btoa_attachment[0][:body].length
    BinaryBlob.count.should == 0
  end

  it "call blob_to_attachment and attachment_to_blob and do not generate attachment filenames" do
    @args[:attachment] = [{:content_type => "application/txt", :filename => "maryhadalittlelamb.txt", :body => "maryhadalittlelamb" * 10},
                          {:content_type => "application/txt", :filename => "itsfleecewaswhiteassnow.txt", :body => "itsfleecewaswhiteassnow" * 10}]
    BinaryBlob.count.should == 0
    atob_attachment = GenericMailer.attachment_to_blob(@args[:attachment])
    BinaryBlob.count.should == 2
    btoa_attachment = GenericMailer.blob_to_attachment(@args[:attachment])
    btoa_attachment[0][:filename].should == "maryhadalittlelamb.txt"
    btoa_attachment[1][:filename].should == "itsfleecewaswhiteassnow.txt"
    @args[:attachment][0][:body].length.should == btoa_attachment[0][:body].length
    BinaryBlob.count.should == 0
  end

  it "call deliver for generic_notification with text/plain attachment" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_mailer_test.txt", :body => "generic_notification with text/plain attachment" * 10}]
    BinaryBlob.count.should == 0
    msg = GenericMailer.deliver(:generic_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
    BinaryBlob.count.should == 0
  end

  it "call deliver for generic_notification with text/html attachment" do
    @args[:attachment] = [{:content_type => "text/html", :filename => "generic_mailer_test.txt", :body => "generic_notification" * 10}]
    msg = GenericMailer.deliver(:generic_notification, @args)
    ActionMailer::Base.deliveries.should == [msg]
  end

  it "call automation_notification directly" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "automation_filename.txt", :body => "automation_notification" * 10}]
    GenericMailer.automation_notification(@args).message.should be_kind_of(Mail::Message)
    ActionMailer::Base.deliveries.should be_empty
  end

  it "call generic_notification directly" do
    @args[:attachment] = [{:content_type => "text/plain", :filename => "generic_filename.txt", :body => "generic_notification" * 10}]
    GenericMailer.generic_notification(@args).message.should be_kind_of(Mail::Message)
    ActionMailer::Base.deliveries.should be_empty
  end

  it "policy_action_email" do
    @args[:miq_action_hash] = {
         :header => "Alert Triggered",
         :policy_detail => "Alert 'Do something on vm start policy', triggered",
         :event_description => "Vm started event!",
         :entity_type => "Vm",
         :entity_name => "My Vm"
    }
    mail = GenericMailer.policy_action_email(@args)
    mail.parts.length.should == 2
    mail.mime_type.should == "multipart/alternative"
    mail.parts[0].mime_type.should == "text/plain"
    mail.parts[0].body.should =~ /Do something on vm start policy/
    mail.parts[1].mime_type.should == "text/html"
    mail.parts[1].body.should =~ /<h3>[\s]*Alert Triggered[\s]*<\/h3>/
  end

  describe "#test_mail" do
    it "should be called directly" do
      GenericMailer.test_email(@args[:to], settings = {})
    end

    it "should not change the input parameters" do
      settings = {:host => "localhost"}
      GenericMailer.test_email(@args[:to], settings)
      settings[:host].should == "localhost"
    end
  end
end
