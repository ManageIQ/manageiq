module ArchivedMixin
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(:deleted_on => nil) }
    scope :active, -> { where(:deleted_on => nil) }
    scope :not_archived_before, lambda { |timestamp|
      unscope(:where => :deleted_on).where(arel_table[:deleted_on].eq(nil).or(arel_table[:deleted_on].gteq(timestamp)))
    }
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
    update!(:deleted_on => Time.now.utc)
  end

  def unarchive!
    update!(:deleted_on => nil)
  end
end
