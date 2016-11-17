require_relative 'hawkular_helper'
# VCR Cassettes: Hawkular Services 0.0.13.Final-SNAPSHOT (commit 3cef2062513f4d949aa21a90db51f9cd105cf329)

describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareMessaging do
  vcr_cassete_name = described_class.name.underscore.to_s

  let(:ems_hawkular) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name     => "test",
                         :auth_key => "valid-token",
                         :userid   => test_userid,
                         :password => test_password)
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => test_hostname,
                       :port            => test_port,
                       :authentications => [auth],
                       :zone            => zone)
  end

  let(:eap) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :id                    => 1,
                       :name                  => 'Local',
                       :feed                  => the_feed_id,
                       :ems_ref               => '/t;hawkular/f;#{the_feed_id}/r;Local~~',
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular)
  end

  [:queue, :topic].each do |ms_model|
    describe ms_model do
      let(:ms) do
        if ms_model == :queue
          FactoryGirl.create(:hawkular_middleware_messaging_initialized_queue,
                             :ems_ref               => '/t;hawkular'\
                                                 "/f;#{the_feed_id}/r;Local~~"\
                                                 '/r;Local~%2Fsubsystem%3Dmessaging-activemq%2Fserver%3Ddefault/' \
                                                 'r;Local~%2Fsubsystem%3Dmessaging-activemq%2Fserver%3Ddefault%2Fjms'\
                                                 '-queue%3DDLQ',
                             :ext_management_system => ems_hawkular,
                             :middleware_server     => eap,
                             :messaging_type        => 'JMS Queue')
        else
          FactoryGirl.create(:hawkular_middleware_messaging_initialized_topic,
                             :ems_ref               => '/t;hawkular'\
                                                 "/f;#{the_feed_id}/r;Local~~"\
                                                 '/r;Local~%2Fsubsystem%3Dmessaging-activemq%2Fserver%3Ddefault'\
                                                 '/r;Local~%2Fsubsystem%3Dmessaging-activemq%2Fserver%3Ddefault%2F'\
                                                 'jms-topic%3DHawkularAlertData',
                             :ext_management_system => ems_hawkular,
                             :middleware_server     => eap,
                             :messaging_type        => 'JMS Topic')
        end
      end

      let(:expected_metrics) do
        if ms_model == :queue
          {
            "JMS Queue Metrics~Consumer Count"   => "mw_ms_queue_consumer_count",
            "JMS Queue Metrics~Delivering Count" => "mw_ms_queue_delivering_count",
            "JMS Queue Metrics~Message Count"    => "mw_ms_queue_message_count",
            "JMS Queue Metrics~Messages Added"   => "mw_ms_queue_messages_added",
            "JMS Queue Metrics~Scheduled Count"  => "mw_ms_queue_scheduled_count"
          }.freeze
        else
          {
            "JMS Topic Metrics~Delivering Count"               => "mw_ms_topic_delivering_count",
            "JMS Topic Metrics~Durable Message Count"          => "mw_ms_topic_durable_message_count",
            "JMS Topic Metrics~Durable Subscription Count"     => "mw_ms_topic_durable_subscription_count",
            "JMS Topic Metrics~Message Count"                  => "mw_ms_topic_message_count",
            "JMS Topic Metrics~Messages Added"                 => "mw_ms_topic_message_added",
            "JMS Topic Metrics~Non-Durable Message Count"      => "mw_ms_topic_non_durable_message_count",
            "JMS Topic Metrics~Non-Durable Subscription Count" => "mw_ms_topic_non_durable_subscription_count",
            "JMS Topic Metrics~Subscription Count"             => "mw_ms_topic_subscription_count"
          }.freeze
        end
      end

      it "#collect_stats_metrics for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          metrics_ids_map, raw_stats = ms.collect_stats_metrics(metrics_available, start_time, end_time, interval)
          expect(metrics_ids_map.keys.size).to be > 0
          expect(raw_stats.keys.size).to be > 0
        end
      end

      it "#collect_live_metrics for all metrics available for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          metrics_data = ms.collect_live_metrics(metrics_available, start_time, end_time, interval)
          keys = metrics_data.keys
          expect(metrics_data[keys[0]].keys.size).to be > 3
        end
      end

      it "#collect_live_metrics for three metrics for #{ms_model}" do
        start_time = test_start_time
        end_time = test_end_time
        interval = 3600
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :match_requests_on              => [:method, :uri, :body],
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          metrics_available = ms.metrics_available
          expect(metrics_available.size).to be > 3
          metrics_data = ms.collect_live_metrics(metrics_available[0, 3],
                                                 start_time,
                                                 end_time,
                                                 interval)
          keys = metrics_data.keys
          # Assuming that for the test the first key has data for 3 metrics
          expect(metrics_data[keys[0]].keys.size).to eq(3)
        end
      end

      it "#first_and_last_capture for #{ms_model}" do
        VCR.use_cassette(vcr_cassete_name,
                         :allow_unused_http_interactions => true,
                         :decode_compressed_response     => true) do # , :record => :new_episodes) do
          capture = ms.first_and_last_capture
          expect(capture.any?).to be true
          expect(capture[0]).to be < capture[1]
        end
      end

      it "#supported_metrics for #{ms_model}" do
        supported_metrics = ms.supported_metrics
        expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }

        model_config = MiddlewareMessaging.live_metrics_config["middleware_messaging_jms_#{ms_model}"]
        supported_metrics = model_config['supported_metrics']
        expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }
      end
    end
  end
end
