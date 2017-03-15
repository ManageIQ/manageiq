class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FIXTURE_DIR = Rails.root.join("db/fixtures")

  include ArRegion
  include ArLock
  include ArNestedCountBy
  include ToModelHash

  extend ArTableLock

  # FIXME: UI code - decorator support
  extend MiqDecorator::Klass
  include MiqDecorator::Instance

  # API Support
  virtual_column :slug, :type => :string

  def slug
    collection = Api::CollectionConfig.new.name_for_subklass(self.class)
    "#{collection}/#{id}" if collection && id
  end
end
