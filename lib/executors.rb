require 'open3'
require_relative 'helpers'


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


def execute_async(commands)
end

# Internal

def print_line(line)
end
