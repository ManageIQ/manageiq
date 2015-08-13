module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid
    helper_method :current_group, :current_groupid, :eligible_groups
    helper_method :current_role, :admin_user?, :super_admin_user?
  end

  def clear_current_user
    User.current_userid = nil
    session[:userid]    = nil
    session[:group]     = nil
  end
  protected :clear_current_user

  def current_user=(db_user)
    User.current_userid = db_user.userid
    session[:userid]    = db_user.userid
    session[:group]     = db_user.current_group.try(:id)
  end
  protected :current_user=

  def eligible_groups
    eligible_groups = current_user.try(:miq_groups)
    eligible_groups = eligible_groups ? eligible_groups.sort_by { |g| g.description.downcase } : []
    eligible_groups.length < 2 ? [] : eligible_groups.collect { |g| [g.description, g.id] }
  end
  private :eligible_groups

  def current_role
    @current_role ||= begin
      role = current_user.try(:miq_user_role)
      role.try(:read_only?) ? role.name.split("-").last : ""
    end
  end
  protected :current_role

  def admin_user?
    current_user.admin_user?
  end
  protected :admin_user?

  def super_admin_user?
    current_user.super_admin_user?
  end
  protected :super_admin_user?

  def current_user
    @current_user ||= User.find_by_userid(session[:userid])
  end
  protected :current_user

  # current_user.userid
  def current_userid
    session[:userid]
  end
  protected :current_userid

  def current_group
    current_user.current_group
  end

  def current_groupid
    current_user.current_group.id
  end
  protected :current_groupid

  def current_userrole
    session[:userrole]
  end
  protected :current_userrole
end
