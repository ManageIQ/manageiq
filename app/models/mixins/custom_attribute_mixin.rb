module CustomAttributeMixin
  extend ActiveSupport::Concern

  CUSTOM_ATTRIBUTES_PREFIX = "virtual_custom_attribute_".freeze
  SECTION_SEPARATOR        = ":SECTION:".freeze
  DEFAULT_SECTION_NAME     = 'Custom Attribute'.freeze

  CUSTOM_ATTRIBUTE_INVALID_NAME_WARNING = "A custom attribute name must begin with a letter (a-z, but also letters with diacritical marks and non-Latin letters) or an underscore (_). Subsequent characters can be letters, underscores, digits (0-9), or dollar signs ($)".freeze
  CUSTOM_ATTRIBUTE_VALID_NAME_REGEXP    = /\A[\p{Alpha}_][\p{Alpha}_\d\$]*\z/

  included do
    has_many   :custom_attributes,     :as => :resource, :dependent => :destroy
    has_many   :miq_custom_attributes, -> { where(:source => 'EVM') }, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute"

    # This is a set of helper getter and setter methods to support the transition
    # between "custom_*" fields in the model and using the custom_attributes table.
    (1..9).each do |custom_id|
      custom_str = "custom_#{custom_id}"
      getter     = custom_str.to_sym
      setter     = "#{custom_str}=".to_sym

      define_method(getter) do
        miq_custom_get(custom_str)
      end
      virtual_column getter, :type => :string  # uses not set since miq_custom_get re-queries

      define_method(setter) do |value|
        miq_custom_set(custom_str, value)
      end
    end

    def self.custom_keys
      custom_attr_scope = CustomAttribute.where(:resource_type => base_class.name).where.not(:name => nil).distinct.pluck(:name, :section)
      custom_attr_scope.map do |x|
        "#{x[0]}#{x[1] ? SECTION_SEPARATOR + x[1] : ''}"
      end
    end

    def self.load_custom_attributes_for(cols)
      custom_attributes = CustomAttributeMixin.select_virtual_custom_attributes(cols)
      custom_attributes.each { |custom_attribute| add_custom_attribute(custom_attribute) }
    end

    def self.invalid_custom_attribute_message(attribute)
      "Invalid custom attribute: '#{attribute}'.  #{CUSTOM_ATTRIBUTE_INVALID_NAME_WARNING}"
    end

    def self.add_custom_attribute(custom_attribute)
      return if respond_to?(custom_attribute)
      ActiveSupport::Deprecation.warn(invalid_custom_attribute_message(custom_attribute)) unless custom_attribute.to_s =~ CUSTOM_ATTRIBUTE_VALID_NAME_REGEXP

      ca_sym                 = custom_attribute.to_sym
      without_prefix         = custom_attribute.sub(CUSTOM_ATTRIBUTES_PREFIX, "")
      name_val, section      = without_prefix.split(SECTION_SEPARATOR)
      ca_arel                = custom_attribute_arel(name_val, section)

      virtual_column(ca_sym, :type => :string, :uses => :custom_attributes, :arel => ca_arel)

      define_method(ca_sym) do
        return self[custom_attribute] if has_attribute?(custom_attribute)

        where_args           = {}
        where_args[:name]    = name_val
        where_args[:section] = section if section

        custom_attributes.find_by(where_args).try(:value)
      end
    end

    def self.custom_attribute_arel(name_val, section)
      lambda do |t|
        ca_field    = CustomAttribute.arel_table

        field_where = ca_field[:resource_id].eq(t[:id])
        field_where = field_where.and(ca_field[:resource_type].eq(base_class.name))
        field_where = field_where.and(ca_field[:name].eq(name_val))
        field_where = field_where.and(ca_field[:section].eq(section)) if section

        # Because there is a `find_by` in the `define_method` above, we are
        # using a `take(1)` here as well, since a limit is assumed in each.
        # Without it, there can be some invalid queries if more than one result
        # is returned.
        t.grouping(ca_field.project(:value).where(field_where).take(1))
      end
    end
  end

  def self.to_human(column)
    col_name, section = column.gsub(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX, '').split(SECTION_SEPARATOR)
    _("%{section}: %{custom_key}") % { :custom_key => col_name, :section => section.try(:titleize) || DEFAULT_SECTION_NAME}
  end

  def self.column_name(custom_key)
    return if custom_key.nil?
    CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX + custom_key
  end

  def self.select_virtual_custom_attributes(cols)
    cols.nil? ? [] : cols.select { |x| x.start_with?(CUSTOM_ATTRIBUTES_PREFIX) }
  end

  def miq_custom_keys
    miq_custom_attributes.pluck(:name)
  end

  def miq_custom_get(key)
    miq_custom_attributes.find_by(:name => key.to_s).try(:value)
  end

  def miq_custom_set(key, value)
    return miq_custom_delete(key) if value.blank?
    ActiveSupport::Deprecation.warn(self.class.invalid_custom_attribute_message(key)) unless key.to_s =~ self.class::CUSTOM_ATTRIBUTE_VALID_NAME_REGEXP

    record = miq_custom_attributes.find_by(:name => key.to_s)
    if record.nil?
      miq_custom_attributes.create(:name => key.to_s, :value => value)
    else
      record.update(:value => value)
    end
  end

  def miq_custom_delete(key)
    miq_custom_attributes.find_by(:name => key.to_s).try(:delete)
  end
end
