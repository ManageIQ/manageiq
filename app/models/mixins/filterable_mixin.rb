module FilterableMixin
  extend ActiveSupport::Concern

  def find_filtered_children(assoc)
    raise "no relationship found for \"#{assoc}\"" unless self.respond_to?(assoc)
    result = self.send(assoc)
    result ? Array.wrap(result) : []
  end

  def authorized_for_user?(userid)
    user     = User.find_by_userid(userid)
    mfilters = user ? user.get_managed_filters : []
    bfilters = user ? user.get_belongsto_filters : []
    db       = self.class
    result   = true

    if db.respond_to?(:find_tags_by_grouping) && !mfilters.empty?
      recs = db.where(:id => id).find_tags_by_grouping(mfilters, :ns => "*").first
      # result = false if recs.nil?
      return false if recs.nil?
    end

    if db.respond_to?(:apply_belongsto_filters)
      result = false unless MiqFilter.apply_belongsto_filters([self], bfilters) == [self]
    end

    result
  end
end
