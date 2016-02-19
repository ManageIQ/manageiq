class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FIXTURE_DIR = Rails.root.join("db/fixtures")

  include ArRegion
  include ArLock
  include ArNestedCountBy
  include ToModelHash

  extend ArTableLock
end
