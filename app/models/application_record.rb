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
end
