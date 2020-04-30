module MiqReportResult::ResultSetOperations
  extend ActiveSupport::Concern

  module ClassMethods
    def apply_limit_and_offset(results, options)
      results.slice(options['offset'].to_i, options['limit'].to_i) || []
    end

    FILTER_PARAMS_MAX_COUNT = 20

    def filter_field(parameter, param_number)
      filter_param_suffix = param_number.zero? ? '' : "_#{param_number}"
      "#{parameter}#{filter_param_suffix}"
    end

    def filtering_enabled?(options)
      options.key?(:filter_column) || options.key?(:filter_column_1)
    end

    def filter_options(options)
      (0...FILTER_PARAMS_MAX_COUNT).each_with_object({}) do |param_number, filter_params|
        param_key = filter_field("filter_column", param_number)
        param_value = options[param_key.to_sym]
        next if param_number.zero? && param_value.nil?

        break(filter_params) unless param_value

        filter_string_column = filter_field("filter_string", param_number).to_sym
        raise ArgumentError, "Value for column #{param_value} (#{param_key} parameter) is missing, please specify #{filter_string_column} parameter" unless options[filter_string_column]

        filter_params[param_value] = options[filter_string_column]
      end
    end

    def result_set_for_reporting(report_result, options)
      report = report_result.report_or_miq_report
      sorting_columns = report.validate_sorting_columns(options[:sort_by])
      result_set = report_result.result_set

      count_of_full_result_set = result_set.count
      if result_set.present? && report
        if filtering_enabled?(options)
          result_set, count_of_full_result_set = report.filter_result_set(result_set, filter_options(options))
          allowed_columns_to_format = report.cols_for_report - filter_options(options).keys
        end

        result_set.map! { |x| x.slice(*report.cols_for_report) }
        result_set = result_set.tabular_sort(sorting_columns, options[:sort_order])
        result_set = apply_limit_and_offset(result_set, options)
      end

      {:result_set => report.format_result_set(result_set, allowed_columns_to_format, options[:expand_value_format]), :count_of_full_result_set => count_of_full_result_set}
    end
  end
end
