class MiqReport < ApplicationRecord
  include ActiveRecord::AttributeAccessorThatYamls

  include_concern 'Formatting'
  include_concern 'Formatters'
  include_concern 'Seeding'
  include_concern 'ImportExport'
  include_concern 'Generator'
  include_concern 'Notification'
  include_concern 'Schedule'
  include_concern 'Search'
  include YAMLImportExportMixin

  serialize :cols
  serialize :conditions
  serialize :where_clause
  serialize :include
  serialize :col_order
  serialize :headers
  serialize :order
  serialize :sortby
  serialize :categories
  serialize :timeline
  serialize :graph
  serialize :db_options
  serialize :generate_cols
  serialize :generate_rows
  serialize :col_formats
  serialize :col_options
  serialize :rpt_options
  serialize :display_filter

  validates_presence_of     :name, :title, :db, :rpt_group
  validates :name, :uniqueness_when_changed => true
  validates_inclusion_of    :rpt_type, :in => %w( Default Custom )

  has_many                  :miq_report_results, :dependent => :destroy
  belongs_to                :time_profile
  belongs_to                :miq_group
  belongs_to                :user
  has_many                  :miq_widgets, :as => :resource

  virtual_column  :human_expression, :type => :string
  virtual_column  :based_on, :type => :string
  virtual_column :col_format_with_defaults, :type => :string_set

  alias_attribute :menu_name, :name
  attr_accessor :ext_options
  attr_accessor_that_yamls :table, :sub_table, :filter_summary, :extras, :ids, :scoped_association, :html_title, :file_name,
                           :extras, :record_id, :tl_times, :user_categories, :trend_data, :performance, :include_for_find,
                           :report_run_time, :chart

  attr_accessor_that_yamls :reserved, :skip_references # For legacy imports

  GROUPINGS = [[:min, N_("Minimum"), N_("Minima")], [:avg, N_("Average"), N_("Averages")], [:max, N_("Maximum"), N_("Maxima")], [:total, N_("Total"), N_("Totals")]].freeze
  PIVOTS    = [[:min, "Minimum"], [:avg, "Average"], [:max, "Maximum"], [:total, "Total"]]
  IMPORT_CLASS_NAMES = %w(MiqReport).freeze

  scope :for_user, lambda { |user|
    if user.report_admin_user?
      all
    else
      where(
        arel_table[:rpt_type].eq('Custom').and(arel_table[:miq_group_id].in(user.current_tenant.miq_groups.pluck(:id)))
        .or(
          arel_table[:rpt_type].eq('Default')
        )
      )
    end
  }

  # Scope on reports that have report results.
  #
  # Valid options are:
  #   ::miq_groups:    An MiqGroups instance on which to filter
  #   ::miq_group_ids: An MiqGroup ids on which to filter
  def self.having_report_results(options = {})
    miq_group_ids = options[:miq_groups].collect(&:id) unless options[:miq_groups].nil?

    miq_group_ids ||= options[:miq_group_ids]
    joins(:miq_report_results).merge(MiqReportResult.for_groups(miq_group_ids)).distinct
  end

  def col_format_with_defaults
    return [] unless cols.present?

    cols.each_with_index.map do |column, index|
      column_format = col_formats.try(:[], index)
      if column_format
        column_format
      else
        column = Chargeback.default_column_for_format(column.to_s) if Chargeback.db_is_chargeback?(db)
        expression_col = col_to_expression_col(column)
        column_type = MiqExpression.parse_field_or_tag(expression_col).try(:column_type)&.to_sym
        MiqReport::Formats.default_format_for_path(expression_col, column_type)
      end
    end
  end

  # NOTE: this can by dynamically manipulated
  def cols
    self[:cols] ||= (self[:col_order] || []).reject { |x| x.include?(".") }
  end

  def human_expression
    conditions.to_human
  end

  def based_on
    Dictionary.gettext(db, :type => :model, :notfound => :titleize)
  end

  def view_filter_columns
    col_order.collect { |c| [headers[col_order.index(c)], c] }
  end

  def self.reportable_models
    MiqExpression.base_tables
  end

  def self.get_expressions_by_model(db)
    reports = where(:db => db.to_s, :template_type => "report")
              .where.not(:conditions => nil)
              .select(:id, :name, :conditions)
              .to_a

    # We have to redo the filtering on ruby side because nil conditions
    # can be serialized as non-NULL value in the database.
    reports = reports.select(&:conditions)

    reports.each_with_object({}) { |report, hash| hash[report.name] = report.id }
  end

  def self.get_col_info(path)
    data_type = MiqExpression.parse_field_or_tag(path).try(:column_type)
    {
      :data_type         => data_type,
      :available_formats => get_available_formats(path, data_type),
      :default_format    => Formats.default_format_for_path(path, data_type),
      :numeric           => [:integer, :decimal, :fixnum, :float].include?(data_type)
    }
  end

  def list_schedules
    exp = MiqExpression.new("=" => {"field" => "MiqReport-id",
                                    "value" => id})
    MiqSchedule.filter_matches_with(exp)
  end

  def add_schedule(data)
    params = data
    params['name'] ||= name
    params['description'] ||= title

    params['filter'] = MiqExpression.new("=" => {"field" => "MiqReport-id",
                                                 "value" => id})
    params['resource_type'] = "MiqReport"
    params['prod_default'] = "system"

    MiqSchedule.create!(params)
  end

  def db_class
    db.kind_of?(Class) ? db : Object.const_get(db)
  end

  def contains_records?
    (extras.key?(:total_html_rows) && extras[:total_html_rows] > 0) ||
      (table && !table.data.empty?)
  end

  def to_hash
    keys = self.class.attr_accessor_that_yamls
    keys.each_with_object(attributes.to_hash) { |k, h| h[k] = send(k) }
  end

  def ascending=(val)
    self.order = val ? "Ascending" : "Descending"
  end

  def ascending?
    order != "Descending"
  end

  def sort_col
    sortby ? col_order.index(sortby.first) : 0
  end

  def column_is_hidden?(col, controller = nil)
    return false unless col_options

    @hidden_cols ||= col_options.keys.each_with_object([]) do |c, a|
      if col_options[c][:hidden]
        a << c
      else
        display_method = col_options[c][:display_method]&.to_sym
        is_display_method_available = defined?(controller.class::DISPLAY_GTL_METHODS) && controller.class::DISPLAY_GTL_METHODS.include?(display_method) && controller.respond_to?(display_method)

        if controller && display_method && is_display_method_available
          # when this display_method returns true it means that column is displayed
          is_column_hidden = !controller.try(display_method)
          a << c if is_column_hidden
        end
      end
    end

    @hidden_cols.include?(col.to_s)
  end

  def self.from_hash(h)
    new(h)
  end

  def page_size
    rpt_options.try(:fetch_path, :pdf, :page_size) || "a4"
  end

  def all_custom_attributes_are_virtual_sql_attributes?
    ca_va_cols = CustomAttributeMixin.select_virtual_custom_attributes(cols)
    ca_va_cols.all? { |custom_attribute| va_sql_cols.include?(custom_attribute) }
  end

  def load_custom_attributes
    return unless db_klass < CustomAttributeMixin || Chargeback.db_is_chargeback?(db)

    db_klass.load_custom_attributes_for(cols.uniq)
  end

  # this method adds :custom_attributes => {} to MiqReport#include
  # when report with virtual custom attributes is stored
  # we need preload custom_attributes table to main query for building report for elimination of superfluous queries
  def add_includes_for_virtual_custom_attributes
    include[:custom_attributes] ||= {} if CustomAttributeMixin.select_virtual_custom_attributes(cols).present?
  end

  # this method removes loading (:custom_attributes => {}) relations for custom_attributes before report is built
  # :custom_attributes => {} was added in method add_includes_for_virtual_custom_attributes in MiqReport#include
  # vc_attributes == Virtual Custom Attributes
  def remove_loading_relations_for_virtual_custom_attributes
    vc_attributes = CustomAttributeMixin.select_virtual_custom_attributes(cols).present?
    include.delete(:custom_attributes) if vc_attributes.present? && include && include[:custom_attributes].blank?
  end

  # determine name column from headers for x-axis in chart
  def chart_header_column
    if graph[:column].blank?
      _log.error("The column for the chart's x-axis must be defined in the report")
      return
    end

    chart_column = MiqExpression::Field.parse(graph[:column]).column
    column_index = col_order.index { |col| col.include?(chart_column) }
    headers[column_index]
  end

  def self.display_name(number = 1)
    n_('Report', 'Reports', number)
  end

  def userid=(_userid)
    # Stubbed method to handle 'userid' attr that may be present in the exported hash
    # which does not exist in the MiqReport class
  end

  def group_description=(_group_description)
    # Stubbed method to handle 'group_description' attr that may be present in the exported hash
    # which does not exist in the MiqReport class
  end

  def columns_for_sorting(columns)
    columns = columns.split(",") if columns && columns.kind_of?(String)

    columns || sortby || col_order
  end

  def validate_sorting_columns(columns)
    validate_columns(columns_for_sorting(columns))
  end

  def validate_columns(sorting_columns)
    Array(sorting_columns).collect do |attr|
      if cols_for_report.include?(attr)
        attr
      else
        raise ArgumentError, N_("%{attribute} is not a valid attribute for %{name}") % {:attribute => attr, :name => name}
      end
    end.compact
  end

  def col_format_hash
    @col_format_hash ||= col_order.zip(col_formats).to_h
  end

  def format_row(row, allowed_columns = nil, expand_value_format = nil)
    tz = get_time_zone(User.current_user.settings.fetch_path(:display, :timezone).presence || Time.zone)
    row.map do |key, _|
      value = allowed_columns.nil? || allowed_columns&.include?(key) ? format_column(key, row, tz, col_format_hash[key]) : row[key]
      [key, expand_value_format.present? ? { :value => value, :style_class => get_style_class(key, row, tz) } : value]
    end.to_h
  end

  def format_result_set(result_set, skip_columns = nil, hash_value_format = nil)
    result_set.map { |row| format_row(row, skip_columns, hash_value_format) }
  end

  def filter_result_set_record(record, filter_options)
    filter_options.all? { |column, search_string| record[column].include?(search_string) }
  end

  def filter_result_set(result_set, filter_options)
    validated_filter_columns = validate_columns(filter_options.keys)
    formatted_result_set = format_result_set(result_set, validated_filter_columns)
    result_set_filtered = formatted_result_set.select { |record| filter_result_set_record(record, filter_options) }

    [result_set_filtered, result_set_filtered.count]
  end

  def self.default_use_sql_view
    ::Settings.reporting.use_sql_view
  end

  private

  def va_sql_cols
    @va_sql_cols ||= cols.select do |col|
      db_class.virtual_attribute?(col) && db_class.attribute_supported_by_sql?(col)
    end
  end

  def db_klass
    @db_klass ||= db.kind_of?(Class) ? db : Object.const_get(db)
  end
end
