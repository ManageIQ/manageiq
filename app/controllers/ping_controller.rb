class PingController < ApplicationController
  def index
    render :text => 'pong', :status => 200
  end
end
