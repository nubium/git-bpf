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

  def empty?
    get_merges.count == 0
  end

  def start_recreate
    self.set_control_variable 'P', 'in_progress'
  end

  def continue_recreate
    self.set_control_variable 'P', 'in_progress_continue'
  end

  def in_progress?
    ['in_progress', 'in_progress_continue'].include? self.get_control_variable 'P'
  end

  def remove_trace
    unless @file.closed?
      @file.close
    end

    File.unlink('.git/.gitbpf-trace') if File.exists? '.git/.gitbpf-trace'
    File.unlink('.git/.gitbpf-opts') if File.exists? '.git/.gitbpf-opts'
    @file = File.open('.git/.gitbpf-trace', 'a+')
    @file.rewind
  end

  def recreate_branch_trace(trace)
    self.set_control_variable 'B', trace
  end

  def set_source_branch(source)
    self.set_control_variable 'S', source
  end

  def get_source_branch
    self.get_control_variable 'S'
  end

  def set_opts(opts)
    file = File.open('.git/.gitbpf-opts', 'wb')
    file.write(Marshal.dump(opts))
    file.close
  end

  def get_opts
    Marshal.load(File.binread('.git/.gitbpf-opts'))
  end


  def get_merges
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

  def get_control_variable(control_char)
    @file.rewind
    @file.each {
        |line|
      return (line[3 .. -1].strip).gsub("\\n", "\n") if line[0, 3] == "/#{control_char}="
    }
  end

  def set_control_variable(control_char, control_value)
    @file.rewind
    tmp_file = File.open('.git/.gitbpf-trace.tmp', 'w+')
    need_insert = true

    @file.each do |line|
      if line[0, 3] == "/#{control_char}="
        tmp_file.write("/#{control_char}=#{control_value}\n")
        need_insert = false
      else
        tmp_file.write(line.strip + "\n")
      end
    end

    tmp_file.write("/#{control_char}=#{control_value}\n") if need_insert

    tmp_file.close

    @file.close
    FileUtils.mv('.git/.gitbpf-trace.tmp', '.git/.gitbpf-trace')
    @file = File.open('.git/.gitbpf-trace', 'a+')
  end

  protected :get_control_variable, :set_control_variable
end
