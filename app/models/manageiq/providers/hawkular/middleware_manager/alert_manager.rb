module ManageIQ::Providers
  class Hawkular::MiddlewareManager::AlertManager
    require 'hawkular/hawkular_client'

    def initialize(alerts_client)
      @alerts_client = alerts_client
    end

    def process_alert(operation, miq_alert)
      group_trigger = convert_to_group_trigger(miq_alert)
      group_conditions = convert_to_group_conditions(miq_alert)
      case operation
      when :new
        @alerts_client.create_group_trigger(group_trigger)
        @alerts_client.set_group_conditions(group_trigger.id,
                                            :FIRING,
                                            group_conditions)
      when :update
        @alerts_client.update_group_trigger(group_trigger)
        @alerts_client.set_group_conditions(group_trigger.id,
                                            :FIRING,
                                            group_conditions)
      when :delete
        @alerts_client.delete_group_trigger(group_trigger.id)
      end
    end

    def convert_to_group_trigger(miq_alert)
      eval_method = miq_alert[:conditions][:eval_method]
      firing_match = 'ALL'
      # Storing prefixes for Hawkular Metrics integration
      # These prefixes are used by alert_profile_manager.rb on member triggers creation
      context = { 'dataId.hm.type' => 'gauge', 'dataId.hm.prefix' => 'hm_g_' }
      case eval_method
      when "mw_heap_used", "mw_non_heap_used"
        firing_match = 'ANY'
      when "mw_accumulated_gc_duration"
        context = { 'dataId.hm.type' => 'counter', 'dataId.hm.prefix' => 'hm_c_' }
      end
      ::Hawkular::Alerts::Trigger.new('id'          => "MiQ-#{miq_alert[:id]}",
                                      'name'        => miq_alert[:description],
                                      'description' => miq_alert[:description],
                                      'enabled'     => miq_alert[:enabled],
                                      'type'        => :GROUP,
                                      'eventType'   => :EVENT,
                                      'firingMatch' => firing_match,
                                      'context'     => context,
                                      'tags'        => {
                                        'miq.event_type'    => 'hawkular_alert',
                                        'miq.resource_type' => miq_alert[:based_on]
                                      })
    end

    def convert_to_group_conditions(miq_alert)
      eval_method = miq_alert[:conditions][:eval_method]
      options = miq_alert[:conditions][:options]
      case eval_method
      when "mw_accumulated_gc_duration"       then generate_mw_gc_condition(eval_method, options)
      when "mw_heap_used", "mw_non_heap_used" then generate_mw_jvm_conditions(eval_method, options)
      end
    end

    def mw_server_metrics_by_column
      MiddlewareServer.live_metrics_config['middleware_server']['supported_metrics_by_column']
    end

    def generate_mw_gc_condition(eval_method, options)
      c = ::Hawkular::Alerts::Trigger::Condition.new({})
      c.trigger_mode = :FIRING
      c.data_id = mw_server_metrics_by_column[eval_method]
      c.type = :RATE
      c.operator = convert_operator(options[:mw_operator])
      c.threshold = options[:value_mw_garbage_collector].to_i
      ::Hawkular::Alerts::Trigger::GroupConditionsInfo.new([c])
    end

    def generate_mw_jvm_conditions(eval_method, options)
      data_id = mw_server_metrics_by_column[eval_method]
      data2_id = if eval_method == "mw_heap_used" then mw_server_metrics_by_column["mw_heap_max"]
                 else mw_server_metrics_by_column["mw_non_heap_committed"]
                 end
      c = []
      c[0] = generate_mw_compare_condition(data_id, data2_id, :GT, options[:value_mw_greater_than].to_f / 100)
      c[1] = generate_mw_compare_condition(data_id, data2_id, :LT, options[:value_mw_less_than].to_f / 100)
      ::Hawkular::Alerts::Trigger::GroupConditionsInfo.new(c)
    end

    def generate_mw_compare_condition(data_id, data2_id, operator, data2_multiplier)
      c = ::Hawkular::Alerts::Trigger::Condition.new({})
      c.trigger_mode = :FIRING
      c.data_id = data_id
      c.data2_id = data2_id
      c.type = :COMPARE
      c.operator = operator
      c.data2_multiplier = data2_multiplier
      c
    end

    def convert_operator(op)
      case op
      when "<"       then :LT
      when "<=", "=" then :LTE
      when ">"       then :GT
      when ">="      then :GTE
      end
    end
  end
end
