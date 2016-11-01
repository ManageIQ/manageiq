class ConsumptionController < ApplicationController
  def show
    @layout     = "consumption"
    @showtype   = "consumption"
  end

  menu_section :cons
end
