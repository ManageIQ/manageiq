class MiqExpression::Target
  ParseError = Class.new(StandardError)

  def self.parse!(field)
    parse(field) || raise(ParseError, field)
  end

  # example .parse('Host.vms-host_name')
  # returns hash:
  # {:model_name => Host<ApplicationRecord> , :associations => ['vms']<Array>, :column_name => 'host_name' <String>}
  def self.parse_params(field)
    match = self::REGEX.match(field) || return
    # convert matches to hash to format
    # {:model_name => 'User', :associations => ...}
    parsed_params = Hash[match.names.map(&:to_sym).zip(match.to_a[1..-1])]
    parsed_params[:model_name] = parsed_params[:model_name].classify.safe_constantize || return
    parsed_params[:associations] = parsed_params[:associations].to_s.split(".")
    parsed_params
  end

  attr_reader :model, :associations, :column

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

  def reflections
    klass = model
    associations.collect do |association|
      klass.reflection_with_virtual(association).tap do |reflection|
        raise ArgumentError, "One or more associations are invalid: #{associations.join(", ")}" unless reflection
        klass = reflection.klass
      end
    end
  end

  def target
    if associations.none?
      model
    else
      reflections.last.klass
    end
  end
end
