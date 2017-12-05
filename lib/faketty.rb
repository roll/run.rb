# Module API

def apply_faketty(code, faketty: false)
  return faketty ? "script -qefc #{code}" : code
end
