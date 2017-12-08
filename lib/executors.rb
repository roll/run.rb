require 'open3'
require 'colorize'
require_relative 'helpers'
require_relative 'faketty'


# Module API

def execute_sync(commands, environ:{}, quiet:false)
  for command in commands

      # Log process
      if !command.variable && !quiet
        puts("[run] Launched '#{command.code}'\n")
      end

      # Execute process
      if !command.variable
        status = system(command.code)
      else
        output, status = Open3.capture2e(command.code)
        environ[command.variable] = output.strip()
      end

      # Failed process
      if !status
        message = "[run] Command '#{command.code}' has failed"
        print_message('general', {'message' => message})
        exit(1)
      end

  end
end


def execute_async(commands, environ: {}, multiplex: false, quiet: false, faketty: false)

  # Launch processes
  processes = []
  color_iterator = iter_colors()
  for command in commands

    # Log process
    if !quiet
      puts("[run] Launched '#{command.code}'\n")
    end

    # Create process
    color = color_iterator.next()
    stdin, output, process = Open3.popen2e(apply_faketty(command.code, faketty: faketty))
    processes.push([command, process, output, color])
    stdin.close()

  end

  # Wait processes
  while !processes.empty?
    for item, index in processes.each_with_index
      command, process, output, color = item

      # Process output
      if multiplex || index == 0
        ready = IO.select([output], nil, nil, 0.1)
        if ready
          file = ready[0][0]
          line = file.read_nonblock(64)
          _print_line(line, command.name, color, multiplex: multiplex, quiet: quiet)
        end
      end

      # Process finish
      if output.eof?
        if process.value != 0
          line = output.read()
          _print_line(line, command.name, color, multiplex: multiplex, quiet: quiet)
          message = "[run] Command '#{command.code}' has failed"
          print_message('general', {'message' => message})
          exit(1)
        end
        if index == 0
          processes.delete_at(index)
          break
        end
      end

    end
  end

end


# Internal

def _print_line(line, name, color, multiplex: false, quiet: false)
  line = line.gsub("\r\n", "\n")
  if multiplex && !quiet
    print("#{name.colorize(color)} | ")
  end
  puts(line)
end
