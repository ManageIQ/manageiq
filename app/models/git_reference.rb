class GitReference < ApplicationRecord
end

DescendantLoader.instance.load_subclasses(GitReference)
