# used to serve static angular templates from under app/views/angular_template/

class AngularTemplateController < ApplicationController
  include HighVoltage::StaticPage
end
