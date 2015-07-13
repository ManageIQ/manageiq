require 'resource_feeder/lib/resource_feeder'
ActionController::Base.send(:include, ResourceFeeder::Rss, ResourceFeeder::Atom)
