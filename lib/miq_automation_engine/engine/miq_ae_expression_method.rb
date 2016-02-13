require_relative '../../../app/helpers/miq_expression/filter_subst'
module MiqAeEngine
  class MiqAeExpressionMethod
    include FilterSubst
    def initialize(method_obj, obj, inputs)
      @edit = {}
      @name = method_obj.name
      @workspace = obj.workspace
      @inputs = inputs
      @search = MiqSearch.where(:name => method_obj.data).try(:first)
      raise MiqAeException::MethodExpressionNotFound, "Search expression #{method_obj.data} not found" unless @search
      process_filter
    end

    def run
      @search_objects = Rbac.search(:filter => MiqExpression.new(@exp),
                                    :class  => @search.db,
                                    :results_format => :objects).first
      @search_objects.empty? ? error_handler : set_result
    end

    private

    def process_filter
      @exp = @search.filter.exp
      @exp_table = exp_build_table(@exp)
      @qs_tokens = create_tokens
      values = get_args(@qs_tokens.keys.length)
      values.each_with_index { |v, index| @qs_tokens[index+1][:value] = v }
      exp_replace_qs_tokens(@exp, @qs_tokens)
    end

    def result_hash(obj)
      @inputs['attributes'].each_with_object({}) do |attr, hash| 
        hash[attr] = result_simple(obj, attr)
      end
    end

    def result_array
      @search_objects.collect { |obj| result_simple(obj, @inputs['attributes'].first) }
    end

    def result_simple(obj, attr)
      raise MiqAeException::MethodNotDefined, "Undefined method #{attr} in class #{obj.class}" unless obj.respond_to?(attr.to_sym)
      obj.send(attr.to_sym);
    end

    def set_result
      target_object.attributes[attribute_name] = get_value
      @workspace.root['ae_result'] = 'ok'
    end

    def error_handler
      disposition = @inputs['on_empty'] || 'error'
      case disposition.to_sym
      when :error
        set_error
      when :warn
        set_warn
      when :abort
        set_abort
      end
    end

    def set_error
      $miq_ae_logger.error("Expression method ends")
      @workspace.root['ae_result'] = 'error'
    end

    def set_abort
      $miq_ae_logger.error("Expression method aborted")
      raise MiqAeException::AbortInstantiation, "Expression method #{@name} aborted"
    end

    def set_warn
      $miq_ae_logger.warn("Expression method ends")
      @workspace.root['ae_result'] = 'warn'
      set_default_value
    end

    def set_default_value
      return unless @inputs.key?('default')
      target_object.attributes[attribute_name] = @inputs['default']
    end

    def attribute_name
      @inputs['attribute'] || 'method_result'
    end

    def target_object
      @workspace.get_obj_from_path(@inputs['target'] || '.').tap do |obj|
        raise MiqAeException::MethodExpressionTargetObjectMissing, @inputs['target'] unless obj
      end
    end

    def get_value
      case @inputs['result_type'].downcase.to_sym
      when :hash
        result_hash(@search_objects.first)
      when :array
        result_array
      when :simple
        result_simple(@search_objects.first, @inputs['attributes'].first)
      else
        raise MiqAeException::MethodExpressionResultTypeInvalid, "Invalid Result type, should be hash, array or simple"
      end
    end

    def get_args(num_token)
      params = []
      for i in 1..num_token
        key = "arg#{i}"
        raise MiqAeException::MethodParameterNotFound, key unless @inputs.key?(key)
        params[i-1] = @inputs[key]
      end
      params
    end
  end
end
