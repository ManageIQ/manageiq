class ApplicationController
  Feature = Struct.new :role, :name, :accord_name, :tree_name, :title, :container do
    def self.new_with_hash(hash)
      new(*members.collect { |m| hash[m] })
    end

    def accord_hash
      {:name      => accord_name,
       :title     => title,
       :container => container}
    end

    def tree_list_name
      tree_name.to_s
    end
  end
end
