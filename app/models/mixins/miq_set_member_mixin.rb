module MiqSetMemberMixin
  extend ActiveSupport::Concern
  included do
    has_many :miq_set_memberships, :dependent => :delete_all, :as => :member
    has_many :miq_sets, :through => :miq_set_memberships
    alias memberof miq_sets
  end

  module ClassMethods
    def miq_set_class
      @miq_set_class ||= "#{name}Set".constantize
    end

    def sets
      miq_set_class.all
    end
    alias miq_sets sets
  end
end
