require_relative 'task'
require_relative 'helpers'


# Main program

# Arguments
argv = ARGV.clone()

# Path argument
path = 'run.yml'
if argv.include?('--run-path')
  index = argv.index('--run-path')
  path = argv.delete_at(index + 1)
  argv.delete_at(index)
end

# Complete argument
complete = false
if argv.include?('--run-complete')
  argv.delete('--run-complete')
  complete = true
end

# Prepare
config, options = read_config(path)
task = Task.new(config, options: options)

# Complete
if complete
  task.complete(argv)
  exit()
end

# Run
task.run(argv)
