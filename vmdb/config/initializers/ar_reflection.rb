begin
  ActiveRecord::Relation.instance_method(:references)
  puts "Rails is new enough to have `references`, please remove this: #{__FILE__}"
rescue NameError
  class ActiveRecord::Relation
    def references(other)
      joins(other)
    end
  end
end
