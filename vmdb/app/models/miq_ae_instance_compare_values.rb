class MiqAeInstanceCompareValues
  attr_reader :compatibilities
  attr_reader :incompatibilities
  attr_reader :fields_in_use
  attr_reader :adds
  IGNORE_PROPERTY_NAMES  = %w(name owner created_on updated_on updated_by
                              updated_by_user_id id class_id instance_id field_id)
  WARNING_PROPERTY_NAMES = %w(priority message display_name default_value substitute
                              visibility collect scope description condition on_entry
                              on_exit on_error max_retries max_time)
  ERROR_PROPERTY_NAMES   = %w(aetype datatype)

  CONGRUENT_INSTANCE = 1
  COMPATIBLE_INSTANCE = 2
  INCOMPATIBLE_INSTANCE = 4

  def initialize(new_instance, old_instance)
    @new_instance = new_instance
    @old_instance = old_instance
  end

  def compare
    load_field_names
    initialize_results
    venn_list
    validate_similar
    status
  end

  def status
    return CONGRUENT_INSTANCE if congruent?
    return COMPATIBLE_INSTANCE if compatible?
    INCOMPATIBLE_INSTANCE
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
    @old_names = @old_instance.field_names
    @new_names = @new_instance.field_names
  end

  def venn_list
    @similar = @new_names & @old_names
    @adds    = @new_names - @old_names
    @deletes = @old_names - @new_names
  end

  def validate_similar
    @similar.each do |name|
      old_value = @old_instance.field_value_hash(name)
      new_value = @new_instance.field_value_hash(name)
      compare_value_properties(name, old_value, new_value)
    end
  end

  def compare_value_properties(field_name, old_value, new_value)
    old_value.each do |property, data|
      next if IGNORE_PROPERTY_NAMES.include?(property)
      next if data == new_value[property]
      hash = {'property'   => property,
              'old_data'   => data,
              'new_data'   => new_value[property],
              'field_name' => field_name}
      @compatibilities   << hash if WARNING_PROPERTY_NAMES.include?(property)
      @incompatibilities << hash if ERROR_PROPERTY_NAMES.include?(property)
    end
  end
end
