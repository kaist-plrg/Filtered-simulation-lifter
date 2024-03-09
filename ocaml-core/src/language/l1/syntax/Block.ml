open StdlibExt
open Basic
include Common_language.BlockF.Make (Inst) (Jmp)

let from_partial (b : L1Partial.Block.t) : t =
  { fLoc = b.fLoc; loc = b.loc; body = b.body; jmp = Jmp.from_partial b.jmp }
