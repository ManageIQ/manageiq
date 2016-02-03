require_relative "../../aws_helper"

describe ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream do
  subject do
    ems = FactoryGirl.create(:ems_amazon_with_authentication)
    described_class.new(ems)
  end
  let(:queue_url) { "https://sqs.eu-central-1.amazonaws.com/995412904407/the_queue_name" }

  describe "#find_or_create_queue" do
    context "with queue present on amazon" do
      it "finds the queue" do
        with_aws_stubbed(:sqs => {:get_queue_url => {:queue_url => queue_url}}) do
          expect(subject).to receive(:sqs_get_queue_url).and_call_original
          expect(subject).not_to receive(:sqs_create_queue).and_call_original
          expect(subject.send(:find_or_create_queue)).to eq(queue_url)
        end
      end
    end

    context "with no queue present on aws" do
      context "and topic present on aws" do
        it "creates the queue" do
          stubbed_responses = {
            :sqs => {
              :get_queue_url => 'NonExistentQueue',
              :create_queue  => {:queue_url => queue_url}
            },
            :sns => {
              :list_topics => {
                :topics => [{:topic_arn => "arn:aws:sns:region:account-id:#{described_class::AWS_CONFIG_TOPIC}"}]
              }
            }
          }
          with_aws_stubbed(stubbed_responses) do
            expect(subject).to receive(:sqs_get_queue_url).and_call_original
            expect(subject).to receive(:sqs_create_queue).and_call_original
            expect(subject).to receive(:subscribe_topic_to_queue).and_call_original
            expect(subject.send(:find_or_create_queue)).to eq(queue_url)
          end
        end
      end

      context "and no topic present on aws" do
        it "raises ProviderUnreachable" do
          stubbed_responses = {
            :sqs => {
              :get_queue_url => 'NonExistentQueue'
            },
            :sns => {
              :list_topics => {
                :topics => [{:topic_arn => "arn:aws:sns:region:account-id:not-the-right-topic"}]
              }
            }
          }
          with_aws_stubbed(stubbed_responses) do
            expect(subject).to receive(:sqs_get_queue_url).and_call_original
            expect(subject).not_to receive(:sqs_create_queue).and_call_original
            expect(subject).not_to receive(:subscribe_topic_to_queue).and_call_original
            expect { subject.send(:find_or_create_queue) }.to raise_exception(described_class::ProviderUnreachable)
          end
        end
      end
    end
  end

  context "#parse_event" do
    let(:message) do
      body = File.read(File.join(File.dirname(__FILE__), "sqs_message.json"))
      Aws::SQS::Types::Message.new(:body => body, :message_id => 1)
    end

    it "parses a SNS Message" do
      expect(subject.send(:parse_event, message)).to include('messageId'   => 1,
                                                             "messageType" => "ConfigurationItemChangeNotification",
                                                             "eventType"   => "AWS_EC2_Instance_UPDATE")
    end
  end

  context "#poll" do
    it "yields an event" do
      message_body = File.read(File.join(File.dirname(__FILE__), "sqs_message.json"))
      stubbed_responses = {
        :sqs => {
          :get_queue_url   => {:queue_url => queue_url},
          :receive_message => [
            {
              :messages => [
                {
                  :body           => message_body,
                  :receipt_handle => 'receipt_handle',
                  :message_id     => 'id'
                }
              ]
            },
            # second message raises an exception
            "Aws::SQS::Errors::ServiceError"
          ]
        }
      }
      with_aws_stubbed(stubbed_responses) do
        allow(subject).to receive(:parse_event).and_return(message_body)
        expect(subject)
        polled_event = nil
        expect do
          subject.poll do |event|
            polled_event = event
          end
        end.to raise_exception(described_class::ProviderUnreachable)
        expect(polled_event).to eq(message_body)
      end
    end
  end
end
