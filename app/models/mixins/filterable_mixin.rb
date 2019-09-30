module FilterableMixin
  extend ActiveSupport::Concern

  def authorized_for_user?(userid)
    user     = User.lookup_by_userid(userid)
    mfilters = user ? user.get_managed_filters : []
    bfilters = user ? user.get_belongsto_filters : []
    db       = self.class
    result   = true

    if db.respond_to?(:find_tags_by_grouping) && !mfilters.empty?
      recs = db.where(:id => id).find_tags_by_grouping(mfilters, :ns => "*").first
      return false if recs.nil?
    end

    if db.respond_to?(:apply_belongsto_filters)
      result = false unless MiqFilter.apply_belongsto_filters([self], bfilters) == [self]
    end

    result
  end
end
