describe ManageIQ::Providers::Google::CloudManager::EventCatcher::Stream do
  require 'fog/google'

  let(:ems)               { FactoryGirl.create(:ems_google_with_project) }
  let(:subscription)      { Fog::Google::Pubsub::Subscription.new }
  let(:pubsub_connection) { ems.connect(:service => 'pubsub') }
  let(:stream)            { described_class.new(ems) }
  let(:subscription_name) { "projects/GOOGLE_PROJECT/subscriptions/manageiq-eventcatcher-#{ems.guid}" }

  before(:all) { Fog.mock! }
  after(:all)  { Fog.unmock! }

  describe '#events' do
    before do
      allow(ems).to    receive(:with_provider_connection).and_yield(pubsub_connection)
      allow(stream).to receive(:get_or_create_subscription).and_return(true)
      allow(stream).to receive(:pull_subscription).and_return([])
    end

    it "acknowledges received messages" do
      expect(stream).to receive(:acknowledge_messages)
      stream.send(:events)
    end
  end

  describe '#get_or_create_subscription' do
    let(:stub_subscriptions) { double }
    subject { stream.send(:get_or_create_subscription, pubsub_connection) }

    before { allow(pubsub_connection).to receive(:subscriptions).and_return(stub_subscriptions) }

    context "when subscription exists" do
      before { allow(stub_subscriptions).to receive(:get).and_return(subscription) }

      it { is_expected.to be(subscription) }

      it "doesn't create new subscription" do
        expect(stub_subscriptions).not_to receive(:create)
        subject
      end
    end

    context "when no subscription is available" do
      before(:all) { RSpec::Mocks.configuration.allow_message_expectations_on_nil = true }
      after(:all) { RSpec::Mocks.configuration.allow_message_expectations_on_nil = false }
      before do
        allow(stub_subscriptions).to receive(:get).and_return(nil)
        allow(stub_subscriptions).to receive(:create).and_return(subscription)
      end

      it { is_expected.to be(subscription) }

      it "has correct subscription_name and topic_name" do
        expect(stub_subscriptions).to receive(:create).with hash_including(
          :name  => subscription_name,
          :topic => "projects/GOOGLE_PROJECT/topics/manageiq-activity-log"
        )
        subject
      end

      it "tries to find the subscription first" do
        expect(stub_subscriptions).to receive(:get).ordered
        expect(stub_subscriptions).to receive(:create).ordered
        subject
      end
    end
  end

  describe '#pull_subscription' do
    require "google/apis/pubsub_#{Fog::Google::Pubsub::GOOGLE_PUBSUB_API_VERSION}"

    let(:messages) { [] }
    let(:response) { Google::Apis::PubsubV1::PullResponse.new(:received_messages => messages) }
    subject { stream.send(:pull_subscription, pubsub_connection) }

    before do
      allow(pubsub_connection).to receive(:pull_subscription).and_return(response)
    end

    context 'no new messages' do
      it { is_expected.to eq [] }
    end

    context 'message available' do
      let(:message_data) do
        {
          :data => {
            :event_type  => "GCE_OPERATION_DONE",
            :jsonPayload => {}
          }
        }
      end
      let(:message_attributes) do
        {
          :ack_id  => "1234ABCD",
          :message => Google::Apis::PubsubV1::Message.new(message_data)
        }
      end
      let(:messages) { [Google::Apis::PubsubV1::ReceivedMessage.new(message_attributes)] }

      it { is_expected.to eq [{ :ack_id => "1234ABCD", :message => message_data }] }
    end
  end

  describe '#acknowledge_messages' do
    let(:messages) do
      [
        {:ack_id => "1"},
        {:ack_id => "2"}
      ]
    end
    subject { stream.send(:acknowledge_messages, pubsub_connection, messages) }

    before do
      allow(pubsub_connection).to receive(:acknowledge_subscription).and_return(true)
    end

    it 'acknowledges all :ack_ids available' do
      expect(pubsub_connection).to receive(:acknowledge_subscription).once.with(subscription_name, %w(1 2))
      subject
    end
  end
end
