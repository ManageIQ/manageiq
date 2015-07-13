# vmdb entries require 'manageiq_foreman'
# once this is moved into a gem, those will not need to change

$LOAD_PATH.unshift File.expand_path('../manageiq_foreman/lib', __FILE__)
require_relative "manageiq_foreman/lib/manageiq_foreman.rb"
