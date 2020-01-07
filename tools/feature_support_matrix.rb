#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'csv'

def usage
  <<-USAGE
    Usage:
      `ruby tools/feature_support_matrix.rb`
  USAGE
end

FeatureMatrix = Struct.new(:model, :features, :subclasses) do
  def supports_nothing?
    features.nil? || features.values.none?
  end

  def accept(visitor)
    visitor.visit(self)
    subclasses.each do |subclass|
      subclass.accept(visitor)
    end
  end
end

def matrix_for(model)
  matrix = FeatureMatrix.new
  matrix.model = model

  if model.included_modules.include?(SupportsFeatureMixin)
    matrix.features = SupportsFeatureMixin::QUERYABLE_FEATURES.keys.each_with_object({}) do |feature, features|
      features[feature] = model.supports?(feature)
    end
  end

  matrix.subclasses = []
  model.subclasses.each do |subclass|
    matrix.subclasses << matrix_for(subclass)
  end

  matrix
end

class CsvVisitor
  def initialize
    @rows = []
  end

  def visit(subject)
    unless subject.supports_nothing?
      row = CSV::Row.new([], [])
      row << {:model => subject.model.name}.merge(subject.features.transform_values { |v| 'x' if v })
      @rows << row
    end
  end

  def to_s
    headers = @rows.first.headers
    CSV.generate('', :headers => headers) do |csv|
      header_row = CSV::Row.new(headers, %w(Model) + SupportsFeatureMixin::QUERYABLE_FEATURES.values)
      csv << header_row
      @rows.each { |row| csv << row }
    end
  end
end

matrix = matrix_for(ApplicationRecord)
csv = CsvVisitor.new
matrix.accept(csv)
puts csv.to_s
