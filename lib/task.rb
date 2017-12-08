require_relative 'plan'
require_relative 'command'


# Module API

class Task

  # Public

  def initialize(descriptor, options: {}, parent: nil, parent_type: nil, quiet: false)
    @parent = parent

    # Prepare
    desc = parent ? '' : 'General run description'
    name, code = Array(descriptor.each_pair)[0]
    if code.kind_of?(Hash)
      desc = code['desc']
      code = code['code']
    end

    # Optional
    optional = false
    if name.start_with?('/')
      name = name[1..-1]
      optional = true
    end

    # Quiet
    if name.include?('!')
      name = name.gsub('!', '')
      quiet = true
    end

    # Directive type
    type = 'directive'

    # Variable type
    if !name.empty? && name == name.upcase
      type = 'variable'
      desc = 'Prints the variable'
    end

    # Sequence type
    childs = []
    if code.kind_of?(Array)
      type = 'sequence'

      # Parent type
      if ['parallel', 'multiplex'].include?(parent_type)
        type = parent_type
      end

      # Parallel type
      if name.start_with?('(') && name.end_with?(')')
        if self.parents.length >= 2
          message = 'Subtask descriptions and execution control not supported'
          print_message('general', {'message' => message})
          exit(1)
        end
        name = name[1..-2]
        type = 'parallel'
      end

      # Multiple type
      if name.start_with?('(') && name.end_with?(')')
        name = name[1..-2]
        type = 'multiplex'
      end

      # Create childs
      for descriptor in code
        if !descriptor.kind_of?(Hash)
          descriptor = {'' => descriptor}
        end
        child = Task.new(descriptor,
            options:options, parent:self, parent_type:type, quiet:quiet)
        childs.push(child)
      end

      # Reset code
      code = nil

    end

    # Set attributes
    @name = name
    @code = code
    @type = type
    @desc = desc
    @quiet = quiet
    @childs = childs
    @options = options
    @optional = optional

  end

  def name()
    return @name
  end

  def code()
    return @code
  end

  def type()
    return @type
  end

  def desc()
    return @desc
  end

  def parent()
    return @parent
  end

  def quiet()
    return @quiet
  end

  def childs()
    return @childs
  end

  def options()
    return @options
  end

  def optional()
    return @optional
  end

  def composite()
    return @childs.length > 0
  end

  def is_root()
    return !@parent
  end

  def parents()
    parents = []
    task = self
    while true
      if !task.parent
        break
      end
      parents.push(task.parent)
      task = task.parent
    end
    return parents.reverse
  end

  def qualified_name()
    names = []
    for parent in self.parents + [self]
      if !parent.name.empty?
        names.push(parent.name)
      end
    end
    return names.join(' ')
  end

  def flatten_setup_tasks()
    tasks = []
    for parent in self.parents
      for task in parent.childs
        if task == self
          break
        end
        if self.parents.include?(task)
          break
        end
        if task.type == 'variable'
          tasks.push(task)
        end
      end
    end
    return tasks
  end

  def flatten_general_tasks()
    tasks = []
    for task in self.composite ? self.childs : [self]
      if task.composite
        tasks = tasks + task.flatten_general_tasks
        next
      end
      tasks.push(task)
    end
    return tasks
  end

  def flatten_childs_with_composite()
    tasks = []
    for task in self.childs
      tasks.push(task)
      if task.composite
        tasks = tasks + task.flatten_childs_with_composite
      end
    end
    return tasks
  end

  def find_child_tasks_by_name(name)
    tasks = []
    for task in self.flatten_general_tasks
      if task.name == name
        tasks.push(task)
      end
    end
    return tasks
  end

  def find_child_task_by_abbrevation(abbrevation)
    letter = abbrevation[0]
    abbrev = abbrevation[1..-1]
    for task in self.childs
      if task.name.start_with?(letter)
        if abbrev
          return task.find_child_task_by_abbrevation(abbrev)
        end
        return task
      end
    end
    return nil
  end

  def run(argv)
    commands = []

    # Delegate by name
    if argv.length > 0
      for task in self.childs
        if task.name == argv[0]
          return task.run(argv[1..-1])
        end
      end
    end

    # Delegate by abbrevation
    if argv.length > 0
      if self.is_root
        task = self.find_child_task_by_abbrevation(argv[0])
        if task
          return task.run(argv[1..-1])
        end
      end
    end

    # Root task
    if self.is_root
      if argv.length > 0 && argv != ['?']
        message = "Task '#{argv[0]}' not found"
        print_message('general', {'message' => message})
        exit(1)
      end
      _print_help(self, self)
      return true
    end

    # Prepare filters
    filters = {'pick' => [], 'enable' => [], 'disable' => []}
    for name, prefix in [['pick', '='], ['enable', '+'], ['disable', '-']]
      for arg in argv.clone
        if arg.start_with?(prefix)
          childs = self.find_child_tasks_by_name(arg[1..-1])
          if !childs.empty?
            filters[name] = filters[name] + childs
            argv.delete(arg)
          end
        end
      end
    end

    # Detect help
    help = false
    if argv == ['?']
      argv.pop()
      help = true
    end

    # Collect setup commands
    for task in self.flatten_setup_tasks
      command = Command.new(task.qualified_name, task.code, variable: task.name)
      commands.push(command)
    end

    # Collect general commands
    for task in self.flatten_general_tasks
      if task != self && !filters['pick'].include?(task)
        if task.optional && !filters['enable'].include?(task)
          next
        end
        if filters['disable'].include?(task)
          next
        end
        if !filters['pick'].empty?
          next
        end
      end
      variable = task.type == 'variable' ? task.name : nil
      command = Command.new(task.qualified_name, task.code, variable: variable)
      commands.push(command)
    end

    # Normalize arguments
    arguments_index = nil
    for command, index in commands.each_with_index
      if command.code.include?('$RUNARGS')
        if !command.variable
          arguments_index = index
          next
        end
      end
      if arguments_index != nil
        command.code = command.code.replace('$RUNARGS', '')
      end
    end

    # Provide arguments
    if arguments_index == nil
      for command, index in commands.each_with_index
        if !command.variable
          command.code("#{command.code} $RUNARGS")
          break
        end
      end
    end

    # Create plan
    plan = Plan.new(commands, self.type)

    # Show help
    if help
      task = self.parents.length < 2 ? self : self.parents[1]
      _print_help(task, self, plan: plan, filters: filters)
      exit()
    end

    # Execute commands
    plan.execute(argv,
      quiet: self.quiet,
      faketty: self.options.fetch('faketty', false))

    return true
  end

  def complete(argv)

    # Delegate by name
    if argv.length > 0
      for task in self.childs
        if task.name == argv[0]
          return task.complete(argv[1..-1])
        end
      end
    end

    # Autocomplete
    for child in self.childs
      if child.name
        print(child.name)
      end
    end

    return true
  end

end


# Internal

def _print_help(task, selected_task, plan: nil, filters: nil)

  # General
  print_message('general', {'message' => task.qualified_name})
  print_message('general', {'message' =>  "\n---"})
  if !task.desc.empty?
    print_message('general', {'message' => "\nDescription\n"})
    puts(task.desc)
  end

  # Vars
  header = false
  for child in [task] + task.flatten_childs_with_composite
    if child.type == 'variable'
      if !header
        print_message('general', {'message' => "\nVars\n"})
        header = true
      end
      puts(child.qualified_name)
    end
  end

  # Tasks
  header = false
  for child in [task] + task.flatten_childs_with_composite
    if child.name.empty?
      next
    end
    if child.type == 'variable'
      next
    end
    if !header
      print_message('general', {'message' => "\nTasks\n"})
      header = true
    end
    message = child.qualified_name
    if child.optional
      message += ' (optional)'
    end
    if filters
      if filters['pick'].include?(child)
        message += ' (picked)'
      end
      if filters['enable'].include?(child)
        message += ' (enabled)'
      end
      if filters['disable'].include?(child)
        message += ' (disabled)'
      end
    end
    if child == selected_task
      message += ' (selected)'
      print_message('general', {'message' => message})
    else
      puts(message)
    end
  end

  # Execution plan
  if plan
    print_message('general', {'message' => "\nExecution Plan\n"})
    puts(plan.explain())
  end

end
