class ProviderConnection < ActiveRecord::Base
  attr_accessible :ipaddress, :port, :provider_component, :hostname
  belongs_to      :ext_management_system, :foreign_key => "ems_id", :polymorphic => true
  validates       :hostname, :ipaddress, :presence => true, :uniqueness => {:case_sensitive => false},
    :if => :hostname_ipaddress_required?

  include AuthenticationMixin

  def verify_credentials(auth_type = nil, _options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?
    ems = ExtManagementSystem.find_by_id(ems_id)

    ems.verify_credentials(auth_type, make_options_hash(auth_type))
  end

  def make_options_hash(_auth_type = nil)
    {
      :user      => username,
      :password  => password,
      :ipaddress => ipaddress,
      :port      => port
    }
  end

  def username
    authentications.first.userid
  end

  def password
    authentications.first.password
  end

  def hostname_ipaddress_required?
    true
  end
end
