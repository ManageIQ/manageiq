module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid
    helper_method :current_group, :current_group_id
    helper_method :admin_user?, :super_admin_user?
    private :clear_current_user
  end

  def clear_current_user
    User.current_user = nil
    session[:userid]  = nil
    session[:group] = nil
  end

  def current_user=(db_user)
    User.current_user = db_user
    session[:userid]  = db_user.userid
    session[:group]   = db_user.current_group_id
  end

  def admin_user?
    current_user.try(:admin_user?)
  end

  def super_admin_user?
    current_user.try(:super_admin_user?)
  end

  def current_user
    if current_userid
      @current_user ||= User.find_by_userid(current_userid).tap do |u|
        u.current_group_id = session[:group] if session[:group]
      end
    end
    @current_user
  end

  # current_user.userid
  def current_userid
    session[:userid]
  end

  delegate :current_group, :to => :current_user

  def current_group_id
    current_user.current_group.id
  end
end
