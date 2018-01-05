require 'rspec'
require '../lib/git_bpf/commands/recreate-branch'
require '../lib/git_bpf/commands/init'

describe 'GIT-BPF-recreate' do
  before :each do
    @tmp_dir='/tmp/git-bpf-tmp-test' + String(rand)
    @repository_dir=@tmp_dir + '/repository/'
    @server_dir=@tmp_dir + '/server/'
    FileUtils.mkdir(@tmp_dir)
    FileUtils.mkdir(@repository_dir)
    FileUtils.mkdir(@server_dir)
    Dir.chdir(@server_dir)
    `git init --bare`
    Dir.chdir(@repository_dir)
    `git init`
    `git remote add stable #{@server_dir}`

    init = Init.new
    allow(STDIN).to receive(:gets) { 'y' }
    expect { init.run('init', '-r', 'stable', '--skip-create-hooks', '-a', 'master') }.to output(//).to_stdout # At neni videt bordel
  end

  it 'should Can show merge commands' do
    File.open(@repository_dir + '/initial', 'w') { |file| file.write("foobar") }
    `git add . && git commit -m "initial"; git push stable master 2>&1`

    `git branch foo && git checkout foo 2>&1`
    File.open(@repository_dir + '/test.conflict', 'w') { |file| file.write("foobar") }
    `git add . && git commit -m "FooBar" && git push stable foo 2>&1`

    `git checkout master 2>&1 && git branch foo2 && git checkout foo2 2>&1`
    File.open(@repository_dir + '/test.non-conflict2', 'w') { |file| file.write("barfoo") }
    `git add . && git commit -m "BarFoo" && git push stable foo2 2>&1`

    `git checkout master 2>&1 && git branch foo3 && git checkout foo3 2>&1`
    File.open(@repository_dir + '/test.non-conflict', 'w') { |file| file.write("barfoo") }
    `git add . && git commit -m "BarFoo" && git push stable foo3 2>&1`

    `git checkout master 2>&1 && git branch integration && git checkout integration 2>&1`

    `git merge --no-ff --no-edit foo`
    `git merge --no-ff --no-edit foo2`
    `git merge --no-ff --no-edit foo3`

    `git checkout master`
    r = RecreateBranch.new
    expect { r.run('recreate-branch', 'integration', '--merges') }.to output(/git merge --no-ff --no-edit stable\/foo && git merge --no-ff --no-edit stable\/foo2 && git merge --no-ff --no-edit stable\/foo3/m).to_stdout
    # Switch back
    expect(`git rev-parse --abbrev-ref HEAD`).to eq("master\n")
  end

end
