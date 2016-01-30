require_relative '../../bundler_setup'
require 'RcuWebService/RcuClientBase'

VC        = raise "please define"
VC_USER     = raise "please define"
VC_PASSWORD   = raise "please define"

FILER     = raise "please define"
FILER_USER    = raise "please define"
FILER_PASSWORD  = raise "please define"

TARGET_HOST = raise "please define"

begin

  rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)

  targetMor = rcu.getMoref(TARGET_HOST, "HostSystem")
  puts "Target host MOR: #{targetMor}"

  datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
    ds.aggrOrVolName  = "rcu_aggr0"
    ds.controller   = RcuHash.new("ControllerSpec") do |cs|
      cs.ipAddress  = FILER
      cs.password   = FILER_PASSWORD
      cs.ssl      = false
      cs.username   = FILER_USER
    end
    ds.datastoreNames = "RichRcuTestTmp"
    ds.numDatastores  = 1
    ds.protocol     = 'NFS'
    ds.sizeInMB     = 1024 * 3 + 10
    ds.targetMor    = targetMor
    ds.thinProvision  = true
    ds.volAutoGrow    = true
    ds.volAutoGrowInc = 1024
    ds.volAutoGrowMax = 1024 * 6
  end

  puts
  puts "Calling createDatastore..."
  rv = rcu.createDatastore(datastoreSpec)

  puts
  puts "*** RV: #{rv} (#{rv.class})"

rescue Handsoap::Fault => hserr
  $stderr.puts hserr.to_s
  $stderr.puts hserr.backtrace.join("\n")
rescue => err
  $stderr.puts err.to_s
  $stderr.puts err.backtrace.join("\n")
end
