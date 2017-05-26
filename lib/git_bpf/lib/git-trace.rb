require 'tmpdir'
require 'fileutils'

class GitTrace
  def initialize
    @file = File.open('.git/.gitbpf-trace', 'a+')
    @file.rewind
  end

  def replace_traces(merges)
    @file.rewind
    @file.write(merges.join("\n"))
  end

  def return_control_structures()
    @file.rewind
  end

  def empty?()
    get_merges.count == 0
  end


  def remove_trace()
    File.unlink('.git/.gitbpf-trace') if File.exists? '.git/.gitbpf-trace'
    File.unlink('.git/.gitbpf-opts') if File.exists? '.git/.gitbpf-opts'
    @file = File.open('.git/.gitbpf-trace', 'a+')
    @file.rewind
  end

  def recreate_branch_trace(trace)
    @file.rewind
    @file.write('/B=' + trace + "\n" + @file.readlines.join("\n"))
  end

  def set_source_branch(source)
    @file.rewind
    @file.write('/S=' + source + "\n" + @file.readlines.join("\n"))
  end

  def set_opts(opts)
    File.open('.git/.gitbpf-opts', 'wb') {|f| f.write(opts)}
  end


  def get_source_branch()
    @file.rewind
    @file.each {
        |line|
      return (line[3 .. -1].strip).gsub("\\n", "\n") if line[0,3] == '/S='
    }
  end

  def get_opts()
    File.binread('.git/.gitbpf-opts')
  end


  def get_merges()
    merges = []

    @file.rewind
    @file.each {
      |line|
      merges << line.strip unless line[0] == '/'
    }

    merges
  end

  def apply_merge(branch)

    @file.rewind
    tmp_file = File.open('.git/.gitbpf-trace.tmp', 'w+')

    @file.each do |line|
      if line.strip == branch.strip
        tmp_file.write('/' + line.strip + "\n")
      else
        tmp_file.write(line.strip + "\n")
      end
    end

    tmp_file.close

    @file.close
    FileUtils.mv('.git/.gitbpf-trace.tmp', '.git/.gitbpf-trace')
    @file = File.open('.git/.gitbpf-trace', 'a+')
    @file.rewind
  end
end