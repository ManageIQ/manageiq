module ArchivedMixin
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(:deleted_on => nil) }
    scope :active, -> { where(:deleted_on => nil) }
  end

  def archived?
    !active?
  end
  alias_method :archived, :archived?

  def active?
    deleted_on.nil?
  end
  alias_method :active, :active?

  def archive!
    update_attributes!(:deleted_on => Time.now.utc)
  end

  def unarchive!
    update_attributes!(:deleted_on => nil)
  end
end
