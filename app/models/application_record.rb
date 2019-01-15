require 'activerecord-id_regions'

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FIXTURE_DIR = Rails.root.join("db/fixtures")

  include ActiveRecord::IdRegions
  include ArRegion
  include ArLock
  include ArNestedCountBy
  include ArHrefSlug
  include ToModelHash

  extend ArTableLock

  # FIXME: UI code - decorator support
  if defined?(ManageIQ::Decorators::Engine)
    extend MiqDecorator::Klass
    include MiqDecorator::Instance
  end

  def self.display_name(number = 1)
    n_(model_name.singular.titleize, model_name.plural.titleize, number)
  end

  def self.human_attribute_name(attribute, options = {})
    return super if options.delete(:ui) == true
    "#{name}: #{super}"
  end

  def self.find_or_create_with_index(index, value, options, &block)
    return unless value
    index.delete(value) || create!(options, &block)
  end

  def self.create_or_update_with_index(index, key, attributes, &block)
    return unless key
    if (rec = index.delete(key))
      rec.attributes = attributes
      if rec.changed?
        yield rec if block_given?
        rec.save!
      end
    else
      create!(attributes, &block)
    end
  end
end
