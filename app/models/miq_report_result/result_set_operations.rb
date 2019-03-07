module MiqReportResult::ResultSetOperations
  extend ActiveSupport::Concern

  module ClassMethods
    def apply_limit_and_offset(results, options)
      results.slice(options['offset'].to_i, options['limit'].to_i) || []
    end

    def format_result_set(miq_report, result_set)
      tz = miq_report.get_time_zone(Time.zone)

      col_format_hash = miq_report.col_order.zip(miq_report.col_formats).to_h

      result_set.map! do |row|
        row.map do |key, _|
          [key, miq_report.format_column(key, row, tz, col_format_hash[key])]
        end.to_h
      end
    end

    def result_set_for_reporting(report_result, options)
      report = report_result.report_or_miq_report
      sorting_columns = report.validate_sorting_columns(options[:sort_by])
      result_set = report_result.result_set
      count_of_full_result_set = result_set.count

      if result_set.present? && report
        result_set = result_set.stable_sort_by(sorting_columns, options[:sort_order])
        result_set.map! { |x| x.slice(*report.col_order) }
        result_set = apply_limit_and_offset(result_set, options)
      end

      {:result_set => format_result_set(report, result_set), :count_of_full_result_set => count_of_full_result_set}
    end
  end
end
