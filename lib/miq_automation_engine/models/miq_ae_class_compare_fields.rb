class MiqAeClassCompareFields
  attr_reader :compatibilities
  attr_reader :incompatibilities
  attr_reader :fields_in_use
  attr_reader :adds
  IGNORE_PROPERTY_NAMES  = %w(name owner created_on updated_on updated_by
                              updated_by_user_id id class_id)
  WARNING_PROPERTY_NAMES = %w(priority message display_name default_value substitute
                              visibility collect scope description condition on_entry
                              on_exit on_error max_retries max_time)
  ERROR_PROPERTY_NAMES   = %w(aetype datatype)

  CONGRUENT_SCHEMA = 1
  COMPATIBLE_SCHEMA = 2
  INCOMPATIBLE_SCHEMA = 4

  def initialize(new_class, old_class)
    @new_class = new_class
    @old_class = old_class
  end

  def compare
    load_field_names
    initialize_results
    venn_list
    validate_similar
    status
  end

  def status
    return CONGRUENT_SCHEMA if congruent?
    return COMPATIBLE_SCHEMA if compatible?
    INCOMPATIBLE_SCHEMA
  end

  def congruent?
    @adds.empty? && @incompatibilities.empty? &&
    @compatibilities.empty? && @fields_in_use.empty? &&
    @deletes.empty?
  end

  def compatible?
    @incompatibilities.empty? && @deletes.empty?
  end

  private

  def initialize_results
    @incompatibilities = []
    @compatibilities   = []
    @fields_in_use     = []
    @adds              = []
    @deletes           = []
  end

  def load_field_names
    @old_names = @old_class.field_names
    @new_names = @new_class.field_names
  end

  def venn_list
    @similar = @new_names & @old_names
    @adds    = @new_names - @old_names
    @deletes = @old_names - @new_names
  end

  def validate_similar
    @similar.each do |name|
      old_field = @old_class.field_hash(name)
      new_field = @new_class.field_hash(name)
      compare_field_properties(name, old_field, new_field)
    end
  end

  def compare_field_properties(field_name, old_field, new_field)
    old_field.each do |property, value|
      next if IGNORE_PROPERTY_NAMES.include?(property)
      next if value == new_field[property]
      hash = {'property'   => property,
              'old_value'  => value,
              'new_value'  => new_field[property],
              'field_name' => field_name}
      @compatibilities   << hash if WARNING_PROPERTY_NAMES.include?(property)
      @incompatibilities << hash if ERROR_PROPERTY_NAMES.include?(property)
    end
  end
end
