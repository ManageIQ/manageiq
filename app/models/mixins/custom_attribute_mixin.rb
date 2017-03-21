module CustomAttributeMixin
  extend ActiveSupport::Concern

  CUSTOM_ATTRIBUTES_PREFIX = "virtual_custom_attribute_".freeze

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
      CustomAttribute.where(:resource_type => base_class).distinct.pluck(:name).compact
    end

    def self.load_custom_attributes_for(cols)
      custom_attributes = CustomAttributeMixin.select_virtual_custom_attributes(cols)
      custom_attributes.each { |custom_attribute| add_custom_attribute(custom_attribute) }
    end

    def self.add_custom_attribute(custom_attribute)
      return if respond_to?(custom_attribute)

      virtual_column(custom_attribute.to_sym, :type => :string, :uses => :custom_attributes)

      define_method(custom_attribute.to_sym) do
        custom_attribute_without_prefix = custom_attribute.sub(CUSTOM_ATTRIBUTES_PREFIX, "")
        custom_attributes.detect { |x| custom_attribute_without_prefix == x.name }.try(:value)
      end
    end
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

    record = miq_custom_attributes.find_by(:name => key.to_s)
    if record.nil?
      miq_custom_attributes.create(:name => key.to_s, :value => value)
    else
      record.update_attributes(:value => value)
    end
  end

  def miq_custom_delete(key)
    miq_custom_attributes.find_by(:name => key.to_s).try(:delete)
  end
end
