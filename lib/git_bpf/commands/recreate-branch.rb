require 'git_bpf/lib/gitflow'
require 'git_bpf/lib/git-helpers'
require 'git_bpf/lib/git-trace'

#
# recreate_branch: Recreate a branch based on the merge commits it's comprised of.
#
class RecreateBranch < GitFlow/'recreate-branch'

  include GitHelpersMixin

  @@prefix = "BRANCH-PER-FEATURE-PREFIX"

  @documentation = "Recreates the source branch in place or as a new branch by re-merging all of the merge commits."


  def options(opts)
    opts.base = nil
    opts.exclude = []
    opts.continueRecreate = false
    opts.abortRecreate = false

    [
      ['-a', '--base NAME',
        "A reference to the commit from which the source branch is based, defaults to #{opts.base}.",
        lambda { |n| opts.base = n }],
      ['-b', '--branch NAME',
        "Instead of deleting the source branch and replacng it with a new branch of the same name, leave the source branch and create a new branch called NAME.",
        lambda { |n| opts.branch = n }],
      ['-x', '--exclude NAME',
        "Specify a list of branches to be excluded.",
        lambda { |n| opts.exclude.push(n) }],
      ['-l', '--list',
        "Process source branch for merge commits and list them. Will not make any changes to any branches.",
        lambda { |n| opts.list = true }],
      ['-d', '--discard',
        "Discard the existing local source branch and checkout a new source branch from the remote if one exists. If no remote is specified with -r, gitbpf will use the configured remote, or origin if none is configured.",
        lambda { |n| opts.discard = true }],
      ['-r', '--remote NAME',
        "Specify the remote repository to work with. Only works with the -d option.",
        lambda { |n| opts.remote = n }],
      ['-v', '--verbose',
        "Show more info about skipping branches etc.",
        lambda { |n| opts.verbose = true }],
      ['-c', '--recreate-base',
       "Recreate base branch (automaticly fetch remote, checkout remote/base to some random name and recreate branch on it)",
       lambda { |n| opts.recreateBranch = true}],
      ['-o', '--abort',
        "Abort recreate branch (discard changes in rr-cache, delete temporary branches)",
        lambda { |n| opts.abortRecreate = true}],
      ['', '--continue', "Continue with recreate-branch",
        lambda { |n| opts.continueRecreate = true}],
      ['', '--merges',
        "Show merge command",
        lambda { |n| opts.showMergeCommand = true }
      ]
    ]
  end

  def execute(opts, argv)
    if argv.length != 1 && opts.continueRecreate == nil
      run('recreate-branch', '--help')
      terminate
    end


    if opts.continueRecreate
      terminate "Parameter --continue can't be used with another parameter" if opts.base || opts.branch || opts.exclude.length > 0 ||
          opts.list || opts.discard || opts.remote || opts.verbose || opts.recreateBranch || opts.abortRecreate || opts.showMergeCommand
    end

    if opts.abortRecreate
      terminate "Parameter --abort can't be used with another parameter" if opts.base || opts.branch || opts.exclude.length > 0 ||
          opts.list || opts.discard || opts.remote || opts.verbose || opts.recreateBranch || opts.continueRecreate || opts.showMergeCommand
    end



    source = argv.pop

    # If no new branch name provided, replace the source branch.
    opts.branch = source if opts.branch == nil

    gt = GitTrace.new

    if opts.abortRecreate
      checkInRecreateProcess(gt)

      # This command returns 128 if git in merge process otherwise do nothing
      is_in_merge = git('merge', 'HEAD', redirect_output_to_null: true, ignore_fail: true, return_git_code: true) == 128

      if is_in_merge
        git('merge', '--abort')
      else
        fail "Git recreate is not in progress or it's complete (not merging)"
      end

      ohai "Aborting"

      rerere_path = File.join("./.git/", 'rr-cache')
      rerere = Repository.new rerere_path
      rerere.reset

      source = gt.get_source_branch
      opts = gt.get_opts
      tmp_source = "#{@@prefix}-#{source}"

      unless opts.remote
        repo = Repository.new(Dir.getwd)
        remote_name = repo.config(true, "--get", "gitbpf.remotename").chomp
        opts.remote = remote_name.empty? ? 'origin' : remote_name
      end

      git('checkout', tmp_source)
      git('branch', '-D', opts.branch)
      git('branch', '-m', opts.branch)
      cleanTemporaryBaseBranch(opts)
      gt.remove_trace


      terminate
    end
    unless opts.continueRecreate
      unless opts.remote
        repo = Repository.new(Dir.getwd)
        remote_name = repo.config(true, "--get", "gitbpf.remotename").chomp
        opts.remote = remote_name.empty? ? 'origin' : remote_name
      end

      opts.selectedBranch = git('rev-parse', '--abbrev-ref', 'HEAD')

      unless opts.base
        base = repo.config(true, "--get", "rerere.defaultbasename", ignore_fail: true)
        ohai "Using base: #{base}"
        opts.base = base.chomp if base

        # Backward compatibility
        unless opts.base
          opts.base = 'master'
        end

      end

      opts.defaultBase = opts.base

      if GitFlow.trace
        ohai "Using base: #{opts.base}"
      end

      if not refExists? opts.base
        terminate "Cannot find reference '#{opts.base}' to use as a base for new branch: #{opts.branch}."
      end

      if opts.recreateBranch
        git('fetch', opts.remote)
        name = "BPF_temp_" + opts.remote + "_" + opts.base + "_" + (Time.new().to_i.to_s) + rand().to_s
        ohai "Checkout #{opts.remote + '/' + opts.base} as #{name}"
        git('checkout', '-B', name, opts.remote + '/' + opts.base)
        git('checkout', source)
        opts.base = name
      end

      if opts.discard
        git('fetch', opts.remote)
        if branchExists?(source, opts.remote)
          opoo "This will delete your local '#{source}' branch if it exists and create it afresh from the #{opts.remote} remote."
          if not promptYN "Continue?"
            terminate "Aborting."
          end
          git('checkout', opts.base)
          git('branch', '-D', source) if branchExists? source
          git('checkout', source)
        end
      end

      # Perform some validation.
      if not branchExists? source
        terminate "Cannot recreate branch #{source} as it doesn't exist."
      end

      if opts.branch != source and branchExists? opts.branch
        terminate "Cannot create branch #{opts.branch} as it already exists."
      end

      #
      # 1. Compile a list of merged branches from source branch.
      #
      ohai "1. Processing branch '#{source}' for merge-commits..."

      branches = getMergedBranches(opts.base, source, opts.verbose)

      if branches.empty?
        cleanTemporaryBaseBranch(opts)
        terminate "No feature branches detected, '#{source}' matches '#{opts.base}'."
      end

      if opts.list
        cleanTemporaryBaseBranch(opts)
        terminate "Branches to be merged:\n#{branches.shell_list}"
      end

      excluded_branches = opts.exclude.map(&:clone)

      # Remove from the list any branches that have been explicity excluded using
      # the -x option
      branches.reject! do |item|
        stripped = item.gsub /^remotes\/\w+\/([\w\-\/]+)$/, '\1'
        puts "Excluding branch #{item}\n" if opts.exclude.include? stripped
        excluded_branches -= [stripped]
        opts.exclude.include? stripped
      end

      if opts.exclude.length > 0
        puts "\n"
      end

      excluded_branches.each do |item|
        opoo "Exclude branch - No match for branch #{item}"
      end

      if opts.showMergeCommand
        ohai "Feel free to run following commands on branch #{opts.defaultBase}:"
        branches.each { |s| s.prepend("git merge --no-ff --no-edit ")}
        puts branches.join(" && ")
        ohai "Switching back"
        git('checkout', opts.selectedBranch)
        cleanTemporaryBaseBranch(opts)
        terminate
      end

      # Prompt to continue.
      opoo "The following branches will be merged when the new #{opts.branch} branch is created:\n#{branches.shell_list}"
      puts
      puts "If you see something unexpected check:"
      puts "a) that your '#{source}' branch is up to date"
      unless opts.recreateBranch
        puts "b) if '#{opts.base}' is a branch, make sure it is also up to date."
      end
      opoo "If there are any non-merge commits in '#{source}', they will not be included in '#{opts.branch}'. You have been warned."
      if not promptYN "Proceed with #{source} branch recreation?"
        cleanTemporaryBaseBranch(opts)
        terminate "Aborting."
      end

      #
      # 2. Backup existing local source branch.
      #
      tmp_source = "#{@@prefix}-#{source}"
      ohai "2. Creating backup of '#{source}', '#{tmp_source}'..."

      if branchExists? tmp_source
        terminate "Cannot create branch #{tmp_source} as one already exists. To continue, #{tmp_source} must be removed."
      end

      gt.start_recreate
      gt.recreate_branch_trace(opts.base)
      gt.set_source_branch(source)
      gt.set_opts(opts)

      git('branch', '-m', source, tmp_source)

      #
      # 3. Create new branch based on 'base'.
      #
      ohai "3. Creating new '#{opts.branch}' branch based on '#{opts.base}'..."

      git('checkout', '-b', opts.branch, opts.base, '--quiet')
      gt.replace_traces(branches)
    else
      is_in_merge = git('merge', 'HEAD', redirect_output_to_null: true, ignore_fail: true, return_git_code: true) == 128

      if is_in_merge
        opoo "Please complete merge before continue"
        terminate
      end

      checkInRecreateProcess(gt)

      source = gt.get_source_branch
      opts = gt.get_opts
      tmp_source = "#{@@prefix}-#{source}"
      branches = gt.get_merges

      gt.continue_recreate

      unless opts.remote
        repo = Repository.new(Dir.getwd)
        remote_name = repo.config(true, "--get", "gitbpf.remotename").chomp
        opts.remote = remote_name.empty? ? 'origin' : remote_name
      end

      opoo "The following branches will be merged to actual branch: \n#{branches.shell_list}"
    end

    #
    # 4. Begin merging in feature branches.
    #
    ohai "4. Merging in feature branches..."

    branches.each do |branch|
      gt.apply_merge(branch)

      begin
        puts " - '#{branch}'"
        # Attempt to merge in the branch. If there is no conflict at all, we
        # just move on to the next one.
        git('merge', '--quiet', '--no-ff', '--no-edit', branch)
      rescue
        # There was a conflict. If there's no available rerere for it then it is
        # unresolved and we need to abort as there's nothing that can be done
        # automatically.
        conflicts = git('rerere', 'remaining').chomp.split("\n")

        if conflicts.length != 0
          puts "\n"
          puts "There is a merge conflict with branch #{branch} that has no rerere."
          puts "Record a resoloution by resolving the conflict."
          puts "Then run the following command to return your repository to its original state."
          puts "\n"
          puts "git checkout #{tmp_source} && git branch -D #{opts.branch} && git branch -m #{opts.branch}"
          if opts.recreateBranch and opts.base
            puts "git branch -D #{opts.base}"
          end
          puts "\n"
          puts "If you do not want to resolve the conflict, it is safe to just run the above command to restore your repository to the state it was in before executing this command."
          terminate
        else
          # Otherwise, we have a rerere and the changes have been staged, so we
          # just need to commit.
          git('commit', '-a', '--no-edit')
        end
      end
    end

    gt.remove_trace

    #
    # 5. Clean up.
    #
    ohai "5. Cleaning up temporary branches ('#{tmp_source}')."

    if source != opts.branch
      git('branch', '-m', tmp_source, source)
    else
      git('branch', '-D', tmp_source)
    end

    cleanTemporaryBaseBranch(opts)

    repo = Repository.new(Dir.getwd)
    begin
      git('branch', '-u', repo.config(true, "--get", "gitbpf.remotename").chomp + '/' + source, source)
    rescue
      opoo "Can't set remote tracking branch"
    end
  end

  def getMergedBranches(base, source, verbose)
    repo = Repository.new(Dir.getwd)
    remote_recreate = repo.config(true, "--get", "gitbpf.remotename").chomp

    branches = []

    merges = git('rev-list', '--merges', '--reverse', '--format=oneline', "#{base}..#{source}").strip.split("\n")

    if verbose
      puts "\nINFO: Branches found between #{base} and #{source}:\n#{merges.shell_list}"
      puts "\n"
    end

    remote_branches = git('branch', '--remote').split("\n")
    remote_branches.map! &:strip

    merges.each do |commits|
      commit_name = commits.split("\s", 2)[1]

      match = commit_name.match(/^Merge (?:remote-tracking )?branch '((.*\/)?(.*))'(.*)?$/)

      unless match
        onoe "Can't match #{commit_name}"
        next
      end

      remote = match[2]
      remote = remote.gsub(/\//, '') unless match[2].nil?

      branch_name = match[3]

      if remote.nil?
        opoo "Local merge detected for #{commit_name} !!!"
      else
        unless remote == remote_recreate
          opoo "Different remote name #{remote}!=#{remote_recreate} for \"#{commit_name}\""
        end
      end


      # TODO: This is not safe, but better than really slooooow ls-remote!
      unless remote_branches.include? (remote_recreate + '/' + branch_name)
        opoo "Can't find remote branch #{remote_recreate}/#{branch_name}. Skipping!"
        next
      end

      branches.push remote_recreate + '/' + branch_name
    end

    puts "\n"

    return branches
  end
end