require 'pty'

module Utils
  def self.message(text)
    $stderr.print(text)
    $stderr.flush
  end

  def self.spawn(command, prefix=true)
    log("utils spawn command='#{command}'")
    IO.popen("#{command} 2>&1", "r") do |io|
      io.sync = true
      output = ""
      begin
        loop do
          if prefix
            output += io.readpartial(80)
            output = print_output(output)
          else
            message(io.readpartial(80))
          end
        end
      rescue EOFError
        prefix ? print_output(output, true) : message(output)
      end
    end
    $?.exitstatus
  end

  def self.nobuffer_rubyopt
    nobuffer_lib = File.expand_path(File.dirname(__FILE__) + "/nobuffer.rb")
    "-r#{nobuffer_lib}"
  end

  def self.spawn_nobuffer(command)
    log("utils spawn_nobuffer command='#{command}'")
    IO.popen("export RUBYOPT=\"#{nobuffer_rubyopt}\"; #{command} 2>&1", "r") do |io|
      io.sync = true
      output = ""
      begin
        loop do
          output += io.readpartial(80)
          output = print_output(output)
        end
      rescue EOFError
        print_output(output, true)
      end
    end
    $?.exitstatus
  end

  def self.print_output(output, last=false)
    while (idx = output.index("\n")) do
      line = output.slice!(0, idx+1)
      message "       #{line}"
    end
    message "       #{output}" if last and output != ""
    output
  end
end
