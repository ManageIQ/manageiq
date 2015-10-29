require "spec_helper"
require "aws-sdk"

describe ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream do
  before do
    @ems = FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

    @ems_stream = described_class.new(@ems.authentication_userid,
                                      @ems.authentication_password,
                                      @ems.provider_region,
                                      @ems.guid)
  end

  context "#each_batch" do
    it "raises ProviderUnreachable on non existing queue" do
      expect(@ems_stream).to receive(:sqs).and_raise(AWS::SQS::Errors::NonExistentQueue)
      @ems_stream.stub(:sns => double(:topics => double(:detect => nil)))

      @ems_stream.start
      expect do
        @ems_stream.each_batch
      end.to raise_error(described_class::ProviderUnreachable)
    end
  end
end
