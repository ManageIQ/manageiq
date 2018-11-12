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
  if defined?(ManageIQ::UI::Classic::Engine)
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
end
