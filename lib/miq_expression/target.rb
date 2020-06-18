class MiqExpression::Target
  ParseError = Class.new(StandardError)

  def self.parse!(field)
    parse(field) || raise(ParseError, field)
  end

  # example .parse('Host.vms-host_name')
  # returns hash:
  # {:model_name => Host<ApplicationRecord> , :associations => ['vms']<Array>, :column_name => 'host_name' <String>}
  def self.parse_params(field)
    return unless field.kind_of?(String)
    match = self::REGEX.match(field) || return
    # convert matches to hash to format
    # {:model_name => 'User', :associations => ...}
    parsed_params = Hash[match.names.map(&:to_sym).zip(match.to_a[1..-1])]
    begin
      parsed_params[:model_name] = parsed_params[:model_name].classify.safe_constantize
    rescue LoadError # issues for case sensitivity (e.g.: VM vs vm)
      parsed_params[:model_name] = nil
    end
    parsed_params[:associations] = parsed_params[:associations].to_s.split(".")
    parsed_params
  end

  attr_reader :column
  attr_accessor :model, :associations

  def initialize(model, associations, column)
    @model = model
    @associations = associations
    @column = column
  end

  def date?
    column_type == :date
  end

  def datetime?
    column_type == :datetime
  end

  def string?
    column_type == :string
  end

  def decimal?
    column_type == :decimal
  end

  def numeric?
    %i(fixnum integer decimal float).include?(column_type)
  end

  def plural?
    return false if reflections.empty?
    [:has_many, :has_and_belongs_to_many].include?(reflections.last.macro)
  end

  def reflection_supported_by_sql?
    model&.follow_associations(associations).present?
  rescue ArgumentError
    false
  end

  # AR or virtual reflections
  def reflections
    model.collect_reflections_with_virtual(associations) ||
      raise(ArgumentError, "One or more associations are invalid: #{associations.join(", ")}")
  end

  # only AR reflections
  def collect_reflections
    model.collect_reflections(associations) ||
      raise(ArgumentError, "One or more associations are invalid: #{associations.join(", ")}")
  end

  def includes
    ret = {}
    model && collect_reflections.map(&:name).inject(ret) { |a, p| a[p] ||= {} }
    ret
  end

  def target
    if associations.none?
      model
    else
      reflections.last.klass
    end
  end

  def tag_path_with(value = nil)
    # encode embedded / characters in values since / is used as a tag seperator
    "#{tag_path}#{value.nil? ? '' : '/' + value.to_s.gsub(/\//, "%2f")}"
  end

  def exclude_col_by_preprocess_options?(options)
    if options.kind_of?(Hash) && options[:vim_performance_daily_adhoc]
      Metric::Rollup.excluded_col_for_expression?(column.to_sym)
    elsif target == Service
      Service::AGGREGATE_ALL_VM_ATTRS.include?(column.to_sym)
    else
      false
    end
  end

  # this should only be accessed in MiqExpression
  # please avoid using it
  def arel_table
    if associations.none?
      model.arel_table
    else
      # if the target attribute is in the same table as the model (the base table),
      # alias the table to avoid conflicting table from clauses
      # seems AR should do this for us...
      ref = reflections.last
      if ref.klass.table_name == model.table_name
        ref.klass.arel_table.alias(ref.alias_candidate(model.table_name))
      else
        ref.klass.arel_table
      end
    end
  end

  # this should only be accessed in MiqExpression
  # please avoid using it
  def arel_attribute
    target&.arel_attribute(column, arel_table)
  end

  private

  def tag_path
    "/#{tag_values.join('/')}"
  end

  def tag_values
    ['virtual'] + @associations + [@column]
  end
end
