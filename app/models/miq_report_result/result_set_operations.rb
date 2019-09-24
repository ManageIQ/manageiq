module MiqReportResult::ResultSetOperations
  extend ActiveSupport::Concern

  module ClassMethods
    def apply_limit_and_offset(results, options)
      results.slice(options['offset'].to_i, options['limit'].to_i) || []
    end

    def result_set_for_reporting(report_result, options)
      report = report_result.report_or_miq_report
      sorting_columns = report.validate_sorting_columns(options[:sort_by])
      result_set = report_result.result_set

      count_of_full_result_set = result_set.count
      if result_set.present? && report
        if options.key?(:filter_column) && options.key?(:filter_string)
          result_set, count_of_full_result_set = report.filter_result_set(result_set, options)
          allowed_columns_to_format = report.col_order - [options[:filter_column]]
        end

        result_set.map! { |x| x.slice(*report.col_order) }
        result_set = result_set.stable_sort_by(sorting_columns, options[:sort_order])
        result_set = apply_limit_and_offset(result_set, options)
      end

      {:result_set => report.format_result_set(result_set, allowed_columns_to_format, options[:expand_value_format]), :count_of_full_result_set => count_of_full_result_set}
    end
  end
end
