class MiqQueueLogFilterer
  class << self
    attr_reader :filter_registry

    # rubocop:disable Naming/MemoizedInstanceVariableName
    def initialize_filter_registry
      @filter_registry ||= {}
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName

    def register_filter(class_name, method_name, filter_method)
      filter_registry[class_name] ||= {}
      filter_registry[class_name][method_name] = filter_method
    end

    def inspect_args_for(queue_msg)
      klass  = queue_msg.class_name
      method = queue_msg.method_name
      args   = queue_msg.args

      if filter_registry.fetch(klass, {})[method]
        klass.constantize.send("filter_args_for_#{method}", args).inspect
      else
        args.inspect
      end
    end
  end

  initialize_filter_registry
end
