require 'yaml'
require 'colorize'


# Module API

def read_config(path='run.yml')

  # Bad file
  if !File.file?(path)
    message = "No '#{path}' found"
    print_message('general', {'message' => message})
    exit(1)
  end

  # Read documents
  documents = []
  contents = File.read(path)
  YAML.load_stream(contents) do |document|
    documents.push(document)
  end

  # Get config
  comments = []
  config = {'run' => []}
  raw_config = documents[0]
  for line in contents.split("\n")

    # Comment begin
    if line.start_with?('# ')
      comments.push(line.gsub('# ', ''))
      next
    end

    # Add config item
    for key, value in raw_config.each_pair
      if line.start_with?(key)
        config['run'].push({key => {'code' => value, 'desc' => comments.join("\n")}})
      end
    end

    # Comment end
    if !line.start_with?('# ')
      comments = []
    end
  end

  # Get options
  options = {}
  if documents.length > 1
    options = documents[1] || {}
  end

  return [config, options]
end


def print_message(type, data)
  puts(data['message'].bold)
end


def iter_colors()
  _COLORS.cycle {|color| yield color}
end


# Internal

_COLORS = [
    'cyan',
    'yellow',
    'green',
    'magenta',
    'red',
    'blue',
    'intense_cyan',
    'intense_yellow',
    'intense_green',
    'intense_magenta',
    'intense_red',
    'intense_blue',
]
