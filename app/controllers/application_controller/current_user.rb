module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid
    helper_method :current_group, :current_groupid
    helper_method :admin_user?, :super_admin_user?
    hide_action :clear_current_user, :current_user=
    hide_action :admin_user?, :super_admin_user?
    hide_action :current_user, :current_userid, :current_groupid
  end

  def clear_current_user
    User.current_userid = nil
    session[:userid]    = nil
    session[:group]     = nil
  end

  def current_user=(db_user)
    User.current_userid = db_user.userid
    session[:userid]    = db_user.userid
    session[:group]     = db_user.current_group.try(:id)
  end

  def admin_user?
    current_user.admin_user?
  end

  def super_admin_user?
    current_user.super_admin_user?
  end

  def current_user
    @current_user ||= User.find_by_userid(session[:userid])
  end

  # current_user.userid
  def current_userid
    session[:userid]
  end

  def current_group
    current_user.current_group
  end

  def current_groupid
    current_user.current_group.id
  end
end
