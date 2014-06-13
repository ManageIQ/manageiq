require "spec_helper"

describe Configuration do
  context ".create_or_update" do
    context "multiple calls do not create multiple records" do
      let(:miq_server) { EvmSpecHelper.create_guid_miq_server_zone[1] }

      it "No changes no updates" do
        create_or_update
        create_or_update

        expect(configuration.updated_on).to                              be_same_time_as(@original_timestamp)
        expect(configuration.settings).to                                eq(@config)
        expect(described_class.where(:typ => "event_handling").count).to eq(1)
      end

      it "Hash changed updates record" do
        create_or_update

        expect(configuration.settings[:some_key][:another_key]).to eq(true)

        @config = {:filtered_events => {:NEW_SKIPPED_EVENT => 1}}

        create_or_update

        expect(configuration.updated_on).to_not                                 be_same_time_as(@original_timestamp)
        expect(configuration.settings[:filtered_events][:NEW_SKIPPED_EVENT]).to eq(1)
      end

      def configuration
        described_class.where(:typ => "event_handling").first
      end

      def create_or_update
        @config ||= {:some_key => {:another_key => true}}
        described_class.create_or_update(miq_server, @config, "event_handling")
        @original_timestamp ||= configuration.updated_on
      end
    end
  end
end
