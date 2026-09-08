module Z3
  # What `#check` came back with. Z3 answers an `LBool`, whose `False` means "no model
  # exists" rather than anything about a Bool expression, so it gets a type of its own
  # rather than leaking `LibZ3` into every `#check`.
  enum CheckResult
    Unsat   = -1
    Unknown =  0
    Sat     =  1

    def self.from_lbool(lbool : LibZ3::LBool) : CheckResult
      case lbool
      when LibZ3::LBool::True
        Sat
      when LibZ3::LBool::False
        Unsat
      when LibZ3::LBool::Undefined
        Unknown
      else
        raise Z3::Exception.new("Wrong SAT result #{lbool}")
      end
    end
  end
end
