require_relative "host/bundler_setup"

$0 = ENV.fetch("MIQ_EXE_NAME", $0).chomp(".exe")

case $0
    when "miq-cmd"
        require "#{File.dirname(__FILE__)}/host/miq-cmd/main"
    else
        require "#{File.dirname(__FILE__)}/host/miqhost/miqhost"
end
