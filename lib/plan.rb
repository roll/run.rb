require_relative 'executors'


# Module API

class Plan

  # Public

  def initialize(commands, mode)
    @commands = commands
    @mode = mode
  end

  def explain()

    # Explain
    lines = []
    plain = true
    for command in @commands
      if ['sequence', 'parallel', 'multiplex'].include?(@mode)
        if !command.variable
          if plain
            lines.push("[#{mode.upcase()}]")
          end
          plain = false
        end
      end
      code = command.code
      if command.variable
        code = "#{command.variable}='#{command.code}'"
      end
      lines.push("#{' ' * (plain ? 0 : 4)}$ #{code}")
    end

    return '\n'.join(lines)

  end

  def execute( argv, quiet:false, faketty:false)
    commands = @commands.clone()

    # Variables
    varnames = []
    variables = []
    for command in commands.clone()
      if command.variable
        variables.push(command)
        varnames.push(command.variable)
        commands.delete(command)
      end
    end
    execute_sync(variables, environ: ENV, quiet:quiet)
    if !(commands.length)
      puts(ENV[varnames[-1]])
      return
    end

    # Update environ
    ENV['RUNARGS'] = argv.join(' ')
    runvars = ENV.fetch('RUNVARS', nil)
    if runvars
      require 'dotenv'
      Dotenv.load(runvars)
    end

    # Log prepared
    if !quiet
      items = []
      start = Time.now
      for name in varnames + ['RUNARGS']
        items.push("#{name}=#{ENV[name]}")
      end
      puts("[run] Prepared '#{items.join('; ')}'")
    end

    # Directive
    if @mode == 'directive'
      execute_sync(commands, environ: ENV, quiet: quiet)

    # Sequence
    elsif @mode == 'sequence'
      execute_sync(commands, environ: ENV, quiet: quiet)

    # Parallel
    elsif @mode == 'parallel'
      execute_async(commands, environ: ENV, quiet: quiet, faketty: faketty)

    # Multiplex
    elsif @mode == 'multiplex'
      execute_async(commands,
        environ: ENV, multiplex: true, quiet: quiet, faketty: faketty)
    end

    # Log finished
    if !quiet
      stop = Time.now
      time = stop - start
      puts("[run] Finished in #{time} seconds")
    end

  end
end
