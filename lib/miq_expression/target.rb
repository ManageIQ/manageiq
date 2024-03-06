class MiqExpression::Target
  # TODO: fix to run against a single regular expression
  # supports strange syntax like: managed.location, Model.x.y.managed-location
  def self.parse(str)
    MiqExpression::Field.parse(str) ||
      MiqExpression::CountField.parse(str) ||
      MiqExpression::Tag.parse(str) ||
      MiqExpression::InvalidTarget.new
  end

  # example .parse('Host.vms-host_name')
  # returns hash:
  # {:model_name => Host<ApplicationRecord> , :associations => ['vms']<Array>, :column_name => 'host_name' <String>}
  def self.parse_params(field)
    return unless field.kind_of?(String)

    parsed_params = match(field)
    return if parsed_params.nil?

    begin
      parsed_params[:model_name] = parsed_params[:model_name].classify.safe_constantize
    rescue LoadError # issues for case sensitivity (e.g.: VM vs vm)
      parsed_params[:model_name] = nil
    end
    parsed_params[:associations] = parsed_params[:associations].to_s.split(".")
    parsed_params
  end

  def self.match(field)
    self::REGEX.match(field)&.named_captures&.symbolize_keys
  end

  attr_reader :column
  attr_accessor :model, :associations

  def initialize(model, associations, column)
    @model = model
    @associations = associations
    @column = column
  end

  def column_type
    nil
  end

  def sub_type
    column_type
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

  def tag?
    false
  end

  def numeric?
    %i[fixnum integer decimal float].include?(column_type)
  end

  def plural?
    return false if reflections.empty?

    [:has_many, :has_and_belongs_to_many].include?(reflections.last.macro)
  end

  def attribute_supported_by_sql?
    reflection_supported_by_sql?
  end

  def reflection_supported_by_sql?
    model&.follow_associations(associations).present?
  rescue ArgumentError
    false
  end

  # @returns AR or virtual reflections
  # @raises ArgumentError
  def reflections
    model.collect_reflections_with_virtual(associations) ||
      raise(ArgumentError, "One or more associations are invalid: #{associations.join(", ")}")
  end

  # @returns only AR reflections
  # @raises ArgumentError
  def collect_reflections
    model.collect_reflections(associations) ||
      raise(ArgumentError, "One or more associations are invalid: #{associations.join(", ")}")
  end

  def includes
    ret = {}
    model && collect_reflections.map(&:name).inject(ret) { |a, p| a[p] ||= {} }
    ret
  rescue ArgumentError
    # since the reflections are not valid, we don't have any includes
    {}
  end

  # @raises ArgumentError
  def target
    if associations.none?
      model
    else
      reflections.last.klass
    end
  end

  def tag_path_with(value = nil)
    # encode embedded / characters in values since / is used as a tag seperator
    "#{tag_path}#{value.nil? ? '' : '/' + value.to_s.gsub("/", "%2f")}"
  end

  def exclude_col_by_preprocess_options?(options)
    if options.kind_of?(Hash) && options[:vim_performance_daily_adhoc]
      Metric::Rollup.excluded_col_for_expression?(column.to_sym)
    elsif target == Service
      Service::AGGREGATE_ALL_VM_ATTRS.include?(column.to_sym)
    else
      false
    end
  rescue ArgumentError # reflections are not valid when looking up target
    false
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
    target && target.arel_table[column, arel_table]
  end

  def virtual_attribute?
    false
  end

  def hash
    [column, associations, model].hash
  end

  def ==(other)
    other.kind_of?(MiqExpression::Target) &&
      column == other.column &&
      model == other.model &&
      associations == other.associations
  end

  def eql?(other)
    other.class == self.class && self == other
  end

  private

  def tag_path
    "/#{tag_values.join('/')}"
  end

  def tag_values
    ['virtual'] + @associations + [@column]
  end
end
