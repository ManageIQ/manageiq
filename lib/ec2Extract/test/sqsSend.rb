require 'rubygems'
require 'aws-sdk'
require_relative '../credentials'

QUEUE_NAME = 'evm_extract_request'

begin

	sqs = AWS::SQS.new(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	
	begin
		queue = sqs.queues.named(QUEUE_NAME)
		puts "Found queue #{QUEUE_NAME}"
	rescue AWS::SQS::Errors::NonExistentQueue => err
		puts "Queue #{QUEUE_NAME} does not exist, creating..."
		queue = sqs.queues.create(QUEUE_NAME)
		puts "Created queue #{QUEUE_NAME}"
	end

	msg = queue.send_message("HELLO")
	puts "Sent message: #{msg.id}"
		
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
