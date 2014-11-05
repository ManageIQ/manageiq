class EmsConnection < ActiveRecord::Base
  # attr_accessible :ems_id, :ipaddress, :port,  :resource_id, :type
    attr_accessible :ipaddress, :port, :provider_component

  has_many   :authentications, :as => :resource, :dependent => :destroy
  belongs_to :ext_management_system, :foreign_key => "ems_id"

  include AuthenticationMixin

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?

    $scvmm_log.info("EmsConnection make_options_hash #{make_options_hash}")


    $scvmm_log.info("#{__FILE__}  #{provider_component}  #{ext_management_system}")

    ext_management_system.verify_credentials(auth_type, make_options_hash(auth_type))
  end

  def make_options_hash(auth_type = nil)
    {
      :user      => self.authentication_userid(auth_type),
      :pass      => self.authentication_password(auth_type),
      :ipaddress => self.ipaddress,
      :port      => self.port

    }
  end

end
