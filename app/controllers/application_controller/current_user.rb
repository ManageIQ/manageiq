module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid
    helper_method :current_group, :current_groupid, :eligible_groups
    helper_method :current_role, :admin_user?, :super_admin_user?
  end

  def clear_current_user
    self.current_user = nil
  end
  protected :clear_current_user

  def current_user=(db_user)
    if db_user
      User.current_userid = db_user.userid
      session[:userid]    = db_user.userid
    else
      User.current_userid = nil
      session[:userid]    = nil
    end
    self.current_group  = db_user.try(:current_group)
  end
  protected :current_user=

  def current_group=(db_group)
    session[:group] = db_group.try(:id)
  end
  private :current_group=

  def eligible_groups
    eligible_groups = current_user.try(:miq_groups)
    eligible_groups = eligible_groups ? eligible_groups.sort_by { |g| g.description.downcase } : []
    eligible_groups.length < 2 ? [] : eligible_groups.collect { |g| [g.description, g.id] }
  end
  private :eligible_groups

  def current_role
    @current_role ||= begin
      role = current_group.try(:miq_user_role)
      role.try(:read_only?) ? role.name.split("-").last : ""
    end
  end
  protected :current_role

  def admin_user?
    %w(super_administrator administrator).include?(current_role)
  end
  protected :admin_user?

  def super_admin_user?
    current_role == "super_administrator"
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
    @current_group ||= MiqGroup.find_by_id(session[:group])
  end

  # current_group.id
  def current_groupid
    session[:group]
  end
  protected :current_groupid

  def current_userrole
    session[:userrole]
  end
  protected :current_userrole
end
