class PingController < ActionController::Base
  protect_from_forgery :secret => SecureRandom.hex(64), :with => :exception

  def index
    render :plain => 'pong', :status => 200
  end
end
