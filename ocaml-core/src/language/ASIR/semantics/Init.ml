open StdlibExt
open Common
open Sem

let from_signature (p : Prog.t) (a : Byte8.t) : State.t =
  let init_sp =
    { SPVal.func = Loc.of_addr a; timestamp = 0L; multiplier = 1L; offset = 0L }
  in
  let f = Prog.get_func_opt p (Loc.of_addr a) |> Option.get in
  let local =
    LocalMemory.add
      (Loc.of_addr a, 0L)
      (Frame.empty (fst f.sp_boundary) (snd f.sp_boundary))
      LocalMemory.empty
  in
  {
    timestamp = 0L;
    sto =
      {
        regs =
          RegFile.add_reg (RegFile.empty p.rspec)
            { id = RegId.Register 32l; offset = 0l; width = 8l }
            (Value.sp init_sp);
        mem = Memory.from_rom p.rom;
        local;
      };
    cursor = { func = Loc.of_addr a; tick = 0L };
    cont = Cont.of_func_entry_loc p (Loc.of_addr a) |> Result.get_ok;
    stack = [];
  }
