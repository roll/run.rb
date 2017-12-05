# Module API

class Task(object):

    # Public

    def __init__(self, descriptor, options={}, parent=None, parent_type=None, quiet=False):
        self._parent = parent

        # Prepare
        desc = '' if parent else 'General run description'
        name, code = list(descriptor.items())[0]
        if isinstance(code, dict):
            desc = code['desc']
            code = code['code']

        # Optional
        optional = False
        if name.startswith('/'):
            name = name[1:]
            optional = True

        # Quiet
        if name.strip(')').endswith('!'):
            name = ''.join(name.rsplit('!', 1))
            quiet = True

        # Directive type
        type = 'directive'

        # Variable type
        if name.isupper():
            type = 'variable'
            desc = 'Prints the variable'

        # Sequence type
        childs = []
        if isinstance(code, list):
            type = 'sequence'

            # Parent type
            if parent_type in ['parallel', 'multiplex']:
                type = parent_type

            # Parallel type
            if name.startswith('(') and name.endswith(')'):
                if len(self.parents) >= 2:
                    message = 'Subtask descriptions and execution control not supported'
                    helpers.print_message('general', message=message)
                    exit(1)
                name = name[1:-1]
                type = 'parallel'

            # Multiple type
            if name.startswith('(') and name.endswith(')'):
                name = name[1:-1]
                type = 'multiplex'

            # Create childs
            for descriptor in code:
                if not isinstance(descriptor, dict):
                    descriptor = {'': descriptor}
                child = Task(descriptor,
                    options=options, parent=self, parent_type=type, quiet=quiet)
                childs.append(child)

            # Reset code
            code = None

        # Set attributes
        self._name = name
        self._code = code
        self._type = type
        self._desc = desc
        self._quiet = quiet
        self._childs = childs
        self._options = options
        self._optional = optional

    def __repr__(self):
        return self.qualified_name

    @property
    def name(self):
        return self._name

    @property
    def code(self):
        return self._code

    @property
    def type(self):
        return self._type

    @property
    def desc(self):
        return self._desc

    @property
    def parent(self):
        return self._parent

    @property
    def quiet(self):
        return self._quiet

    @property
    def childs(self):
        return self._childs

    @property
    def options(self):
        return self._options

    @property
    def optional(self):
        return self._optional

    @property
    def composite(self):
        return bool(self._childs)

    @property
    def is_root(self):
        return bool(not self._parent)

    @property
    def parents(self):
        parents = []
        task = self
        while True:
            if not task.parent:
                break
            parents.append(task.parent)
            task = task.parent
        return list(reversed(parents))

    @property
    def qualified_name(self):
        names = []
        for parent in (self.parents + [self]):
            if parent.name:
                names.append(parent.name)
        return ' '.join(names)

    @property
    def flatten_setup_tasks(self):
        tasks = []
        for parent in self.parents:
            for task in parent.childs:
                if task is self:
                    break
                if task in self.parents:
                    break
                if task.type == 'variable':
                    tasks.append(task)
        return tasks

    @property
    def flatten_general_tasks(self):
        tasks = []
        for task in self.childs or [self]:
            if task.composite:
                tasks.extend(task.flatten_general_tasks)
                continue
            tasks.append(task)
        return tasks

    @property
    def flatten_childs_with_composite(self):
        tasks = []
        for task in self.childs:
            tasks.append(task)
            if task.composite:
                tasks.extend(task.flatten_childs_with_composite)
        return tasks

    def find_child_tasks_by_name(self, name):
        tasks = []
        for task in self.flatten_general_tasks:
            if task.name == name:
                tasks.append(task)
        return tasks

    def find_child_task_by_abbrevation(self, abbrevation):
        letter = abbrevation[0]
        abbrev = abbrevation[1:]
        for task in self.childs:
            if task.name.startswith(letter):
                if abbrev:
                    return task.find_child_task_by_abbrevation(abbrev)
                return task
        return None

    def run(self, argv):
        commands = []

        # Delegate by name
        if len(argv) > 0:
            for task in self.childs:
                if task.name == argv[0]:
                    return task.run(argv[1:])

        # Delegate by abbrevation
        if len(argv) > 0:
            if self.is_root:
                task = self.find_child_task_by_abbrevation(argv[0])
                if task:
                    return task.run(argv[1:])

        # Root task
        if self.is_root:
            if len(argv) > 0 and argv != ['?']:
                message = 'Task "%s" not found' % argv[0]
                helpers.print_message('general', message=message)
                exit(1)
            _print_help(self, self)
            return True

        # Prepare filters
        filters = {'pick': [], 'enable': [], 'disable': []}
        for name, prefix in [['pick', '='], ['enable', '+'], ['disable', '-']]:
            for arg in list(argv):
                if arg.startswith(prefix):
                    childs = self.find_child_tasks_by_name(arg[1:])
                    if childs:
                        filters[name].extend(childs)
                        argv.remove(arg)

        # Detect help
        help = False
        if argv == ['?']:
            argv.pop()
            help = True

        # Collect setup commands
        for task in self.flatten_setup_tasks:
            command = Command(task.qualified_name, task.code, variable=task.name)
            commands.append(command)

        # Collect general commands
        for task in self.flatten_general_tasks:
            if task is not self and task not in filters['pick']:
                if task.optional and task not in filters['enable']:
                    continue
                if task in filters['disable']:
                    continue
                if filters['pick']:
                    continue
            variable = task.name if task.type == 'variable' else None
            command = Command(task.qualified_name, task.code, variable=variable)
            commands.append(command)

        # Normalize arguments
        arguments_index = None
        for index, command in enumerate(commands):
            if '$RUNARGS' in command.code:
                if not command.variable:
                    arguments_index = index
                    continue
            if arguments_index is not None:
                command.code = command.code.replace('$RUNARGS', '')

        # Provide arguments
        if arguments_index is None:
            for index, command in enumerate(commands):
                if not command.variable:
                    command.code = '%s $RUNARGS' % command.code
                    break

        # Create plan
        plan = Plan(commands, self.type)

        # Show help
        if help:
            task = self if len(self.parents) < 2 else self.parents[1]
            _print_help(task, self, plan, filters)
            exit()

        # Execute commands
        plan.execute(argv,
            quiet=self.quiet,
            faketty=self.options.get('faketty'))

        return True

    def complete(self, argv):

        # Delegate by name
        if len(argv) > 0:
            for task in self.childs:
                if task.name == argv[0]:
                    return task.complete(argv[1:])

        # Autocomplete
        for child in self.childs:
            if child.name:
                print(child.name)

        return True


# Internal

def _print_help(task, selected_task, plan=None, filters=None):

    # General
    helpers.print_message('general', message=task.qualified_name)
    helpers.print_message('general', message='\n---')
    if task.desc:
        helpers.print_message('general', message='\nDescription\n')
        print(task.desc)

    # Vars
    header = False
    for child in [task] + task.flatten_childs_with_composite:
        if child.type == 'variable':
            if not header:
                helpers.print_message('general', message='\nVars\n')
                header = True
            print(child.qualified_name)

    # Tasks
    header = False
    for child in [task] + task.flatten_childs_with_composite:
        if not child.name:
            continue
        if child.type == 'variable':
            continue
        if not header:
            helpers.print_message('general', message='\nTasks\n')
            header = True
        message = child.qualified_name
        if child.optional:
            message += ' (optional)'
        if filters:
            if child in filters['pick']:
                message += ' (picked)'
            if child in filters['enable']:
                message += ' (enabled)'
            if child in filters['disable']:
                message += ' (disabled)'
        if child is selected_task:
            message += ' (selected)'
            helpers.print_message('general', message=message)
        else:
            print(message)

    # Execution plan
    if plan:
        helpers.print_message('general', message='\nExecution Plan\n')
        print(plan.explain())
