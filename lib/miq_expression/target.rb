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

  def numeric?
    [:fixnum, :integer, :float].include?(column_type)
  end

  def plural?
    return false if reflections.empty?
    [:has_many, :has_and_belongs_to_many].include?(reflections.last.macro)
  end

  def reflection_supported_by_sql?
    model.follow_associations(associations).present?
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

  private

  def tag_path
    "/#{tag_values.join('/')}"
  end

  def tag_values
    ['virtual'] + @associations + [@column]
  end
end
