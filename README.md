Affinity Bridge's Branch-per-Feature Scripts
============================================

Configure a repository and add some useful [Branch-per-Feature] workflow commands.

Performs the following actions in the target repository:

 - enables ```git-rerere```
 - configures ```git-rerere``` to automatically stage successful resolutions
 - a .git/rr-cache directory will be set up to synchronize with a 'rr-cache' branch in the repository's remote.
 - installs a ```post-merge``` git hook for automatic rr-cache syncing
 - installs the bundled branch-per-feature helper commands

## Commands

### git-recreate-branch

Usage: ```git recreate-branch <source-branch> [OPTIONS]...```

Recreates <source-branch> in-place or as a new branch by re-merging all of the merge commits which it is comprised of.

    OPTIONS
        -a, --base NAME                  A reference to the commit from which the source branch is based, defaults to master.
        -b, --branch NAME                Instead of deleting the source branch and replacng it with a new branch of the same name, leave the source branch and create a new branch called NAME.
        -x, --exclude NAME               Specify a list of branches to be excluded.
        -l, --list                       Process source branch for merge commits and list them. Will not make any changes to any branches.
        -c, --recreate-base              Recreate base branch (automaticly fetch remote, checkout remote/base to some random name and recreate branch on it)


### git-share-rerere

A collection of commands to help share your rr-cache.

    OPTIONS
        -c, --cache_dir DIR              The location of your rr-cache dir, defaults to .git/rr-cache.
        -g, --git-dir DIR                The location of your rr-cache .git dir, defaults to .git/rr-cache/.git.
        -b, --branch NAME                The name of the branch your rr-cache is stored in, defaults to rr-cache.
        -r, --remote NAME                The name of the remote to use when getting the latest rr-cache, defaults to origin.

**Sub-commands - Usage:**

```git share-rerere push```

Push any new resolutions to the designated <branch> on the remote.

```git share-rerere pull```

Pull any new resolutions to the designated <branch> on the remote.

## Install

_Requires git >= 1.7.10.x_

### Install git-bpf-init script

git_bpf is packaged as a Ruby Gem and hosted on [RubyGems]
    
    gem install git_bpf

### Usage

    git-bpf-init <target-repository>

    OPTIONS
        -r, --remote NAME                The name of the remote to use for syncing rr-cache, defaults to origin.
        -e, --remote_recreate NAME       The pattern for choosing branches for recreate-branch command, defaults to wildcard *. Can be used for filtering certain branches from remote repositories

 - If <target-repository> is not provided, <target-repository> defaults to your current directory (will fail if current directory is not a git repository).

## Upgrading

Upgrading from older development versions of these scripts is a little bit sketchy. The steps possible steps involved are detailed [here](https://gist.github.com/tnightingale/59f44847526e1cc20bf7). Read through the document and run the steps that apply to you.

[Branch-per-Feature]: https://github.com/affinitybridge/git-bpf/wiki/Branch-per-feature-process
[RubyGems]: http://rubygems.org/

## Manual install

You need to fetch latest master from this repo. Execute manual gem build
```gem build git_bpf.gemspec```

This will create gemfile git_bpf-1.0.1.gem . To install it, run

```gem install git_bpf-1.0.1.gem```

To use new features in your repo, you need to initialize the repo again.

```git-bpf-init ```

Note for windows users - prior to upgrading git-bpf, you need to remove all hooks and git-bpf directory from .git directory in your project.
