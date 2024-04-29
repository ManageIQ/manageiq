require_relative "instrument"

module Vmdb::Loggers
  class FogLogger < ManageIQ::Loggers::Base
    include Instrument
  end
end
