
require 'pp'
require 'ExtractUserData'
require '../Ec2Payload'

udStr = Ec2Payload.encode(ExtractUserData::user_data)

puts
puts udStr

ud = Ec2Payload.decode(udStr)

puts
pp ud
