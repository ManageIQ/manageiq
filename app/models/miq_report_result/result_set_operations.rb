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

    def filter_result_set(report, result_set, options)
      filter_columns = report.validate_columns(options[:filter_column]) + ['id']
      formatted_result_set = format_result_set(report, result_set.map { |x| x.slice(*filter_columns) })
      result_set_filtered_ids = formatted_result_set.map { |x| x[options[:filter_column]].include?(options[:filter_string]) ? x['id'].to_i : nil }.compact
      [result_set.select! { |x| result_set_filtered_ids.include?(x['id']) }, result_set_filtered_ids.count]
    end

    def result_set_for_reporting(report_result, options)
      report = report_result.report_or_miq_report
      sorting_columns = report.validate_sorting_columns(options[:sort_by])
      result_set = report_result.result_set
      count_of_full_result_set = result_set.count
      if result_set.present? && report
        result_set, count_of_full_result_set = filter_result_set(report, result_set, options) if options.key?(:filter_column) && options.key?(:filter_string)
        result_set.map! { |x| x.slice(*report.col_order) }
        result_set = result_set.stable_sort_by(sorting_columns, options[:sort_order])
        result_set = apply_limit_and_offset(result_set, options)
      end

      {:result_set => format_result_set(report, result_set), :count_of_full_result_set => count_of_full_result_set}
    end
  end
end
