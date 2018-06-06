module ArchivedMixin
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(:deleted_on => nil) }
    scope :active, -> { where(:deleted_on => nil) }
  end

  def archived?
    !active?
  end

  def active?
    deleted_on.nil?
  end
end
