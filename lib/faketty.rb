require 'shellwords'


# Module API

def apply_faketty(code, faketty: false)
  return faketty ? "script -qefc #{Shellwords.escape(code)} /dev/null" : code
end
