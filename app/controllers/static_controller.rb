# used to serve static angular templates from under app/views/static/

class StaticController < ApplicationController
  include HighVoltage::StaticPage
end
