# http://rubyglasses.blogspot.com/2009/07/40-speedup-using-nokogiri.html
# Speeds up Hash#to_xml and Hash.from_xml over rexml backend.
ActiveSupport::XmlMini.backend = :Nokogiri
