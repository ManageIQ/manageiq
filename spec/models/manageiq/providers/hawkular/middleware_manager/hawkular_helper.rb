# Feed id to be used for all spec
def the_feed_id
  '71daaa4b-da76-4373-8753-68279f33a884'.freeze
end

def test_start_time
  Time.new(2016, 10, 19, 8, 00, 0, "+00:00").freeze
end

def test_end_time
  Time.new(2016, 10, 19, 10, 00, 0, "+00:00").freeze
end

def test_hostname
  'hservices.torii.gva.redhat.com'.freeze
end

def test_port
  80
end

def test_userid
  'jdoe'.freeze
end

def test_password
  'password'.freeze
end
