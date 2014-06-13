require 'actionwebservice'

class MiqservicesController < ApplicationController
  acts_as_web_service
  wsdl_service_name 'Miqservices'
  web_service_api MiqservicesApi
  web_service_dispatching_mode :direct
  web_service_scaffold :invoke

  include MiqservicesOps
end
