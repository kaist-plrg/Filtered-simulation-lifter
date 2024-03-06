open StdlibExt
open Basic
open Basic_collection
open Common_language

let from_signature (p : Prog.t) (a : Addr.t) : State.t =
  let init_sp = { SPVal.func = (a, 0); timestamp = 0L; offset = 0L } in
  {
    timestamp = 0L;
    sto =
      {
        regs =
          RegFile.add_reg (RegFile.empty p.rspec)
            { id = RegId.Register 32l; offset = 0l; width = 8l }
            (Value.NonNum (SP init_sp));
        mem = Memory.from_rom p.rom;
        local =
          LocalMemory.store_mem LocalMemory.empty init_sp
            (Value.Num (NumericValue.of_int64 0xDEADBEEFL 8l));
      };
    func = ((a, 0), 0L);
    cont = Cont.of_func_entry_loc p (a, 0) |> Result.get_ok;
    stack = [];
  }