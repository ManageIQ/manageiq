#!/usr/bin/env ruby

class JohnnyFive
  SKIP_FILE=".skip-ci"
  def skip(justification = nil)
    justification = "SKIPPING: #{justification}\n"
    puts justification
    File.write(SKIP_FILE, justification)
  end

  def pr?
    @pr = ENV['TRAVIS_PULL_REQUEST'] != "true" if @pr.nil?
    @pr
  end

  def branch
    @branch ||= ENV['TRAVIS_BRANCH']
  end

  def commit
    @commit ||= ENV['TRAVIS_COMMIT']
  end

  def commit_range
    @commit_range ||= ENV['TRAVIS_COMMIT_RANGE'] || ""
  end

  def first_commit
    @first_commit ||= commit_range.split("...").first
  end

  def last_commit
    @last_commit ||= `git rev-list -n 1 FETCH_HEAD^2`.chomp
  end

  def file_ref
    if pr?
      if first_commit == ""
        # Travis-CI is not yet passing a commit range for pull requests
        # so we must use the automerge's changed file list. This has the
        # negative effect that new pushes to the PR will immediately
        # start affecting any new jobs, regardless of the build they are on
        debug("No first commit, using Github's automerge commit")
        "--first-parent -1 -m FETCH_HEAD"
      elsif first_commit == last_commit
        # There is only one commit in the pull request so far,
        # or Travis-CI is not yet passing the commit range properly
        # for pull requests. We examine just the one commit using -1
        #
        # On the oddball chance that it's a merge commit, we pray
        # it's a merge from upstream and also pass --first-parent
        debug("Only one commit in range, examining #{last_commit}")
        "-m --first-parent -1 #{last_commit}"
      else
        # In case they merged in upstream, we only care about the first
        # parent. For crazier merges, we hope
        "--first-parent #{first_commit}...#{last_commit}"
      end
    else
      debug('I am not testing a pull request')
        # Three main scenarios to consider
        #  - 1 One non-merge commit pushed to master
        #  - 2 One merge commit pushed to master (e.g. a PR was merged).
        #      This is an example of merging a topic branch
        #  - 3 Multiple commits pushed to master
        #
        #  1 and 2 are actually handled the same way, by showing the
        #  changes being brought into to master when that one commit
        #  was merged. Fairly simple, `git log -1 COMMIT`. To handle
        #  the potential merge of a topic branch you also include
        #  `--first-parent -m`.
        #
        #  3 needs to be handled by comparing all merge children for
        #  the entire commit range. The best solution here would *not*
        #  use --first-parent because there is no guarantee that it
        #  reflects changes brought into master. Unfortunately we have
        #  no good method inside Travis-CI to easily differentiate
        #  scenario 1/2 from scenario 3, so I cannot handle them all
        #  separately. 1/2 are the most common cases, 3 with a range
        #  of non-merge commits is the next most common, and 3 with
        #  a range including merge commits is the least common, so I
        #  am choosing to make our Travis-CI setup potential not work
        #  properly on the least common case by always using
        #  --first-parent

        # Handle 3
        # Note: Also handles 2 because Travis-CI sets COMMIT_RANGE for
        # merged PR commits
      "--first-parent -m #{commit_range}"
    end

    # Handle 1
    # "--first-parent -m -1 #{commit}"
  end

  def changed_files
    `git log --name-only --pretty=\"format:\" #{file_ref}`.split("\n")
  end

  def inform
    if pr?
      puts "PR    BRANCH: #{branch}"
      puts "COMMIT_RANGE: #{commit_range}"
      puts "first_commit: #{first_commit}"
      puts "last_commit : #{last_commit}"
      puts "COMMIT      : #{commit}"
    else
      puts "merge into master (#{branch})"
    end
    puts "CHANGED FILES:"
    puts "---"
    puts changed_files.uniq.sort.join("\n")
    puts "---"
  end

  def run
    inform
    #skip("Im being trigger happy") if pr?
  end

  def debug(msg)
    puts "DEBUG: #{msg}"
  end

  def self.run
    new.run
  end
end

JohnnyFive.run
