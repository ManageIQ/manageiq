module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid
    helper_method :current_group, :current_group_id
    helper_method :admin_user?, :super_admin_user?
    hide_action :clear_current_user, :current_user=
    hide_action :admin_user?, :super_admin_user?
    hide_action :current_user, :current_userid, :current_group_id
  end

  def clear_current_user
    User.current_user = nil
    session[:userid]  = nil
  end

  def current_user=(db_user)
    User.current_user = db_user
    session[:userid]  = db_user.userid
  end

  def admin_user?
    current_user.try(:admin_user?)
  end

  def super_admin_user?
    current_user.try(:super_admin_user?)
  end

  def current_user
    @current_user ||= User.find_by_userid(session[:userid]) if current_userid
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
