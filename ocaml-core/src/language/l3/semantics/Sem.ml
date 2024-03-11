module NonNumericValue = NonNumericValue
module Cont = Common_language.ContF.Make (Inst) (Jmp) (Block) (Func) (Prog)
module Value = Common_language.ValueF.Make (NonNumericValue)
module TimeStamp = Common_language.Int64TimeStamp
module Cursor = Common_language.CursorF.Make (TimeStamp)
module RegFile = Common_language.RegFileF.Make (Value)
module Frame = Common_language.FrameF.Make (Value)
module LocalMemory = Common_language.LocalMemoryF.Make (Value) (Frame)
module Memory = Common_language.MemoryF.Make (Value)

module Store =
  Common_language.HighStoreF.Make (Prog) (Value) (Cursor) (RegFile) (Memory)
    (Frame)
    (LocalMemory)

module Stack = struct
  open Basic
  open Basic_collection

  type elem_t = {
    cursor : Cursor.t;
    outputs : RegId.t list;
    sregs : RegFile.t;
    saved_sp : Value.t;
    fallthrough : Loc.t;
  }

  type t = elem_t list

  let get_fallthrough (v : elem_t) = v.fallthrough
  let get_cursor (v : elem_t) = v.cursor

  let pp fmt (v : t) =
    let pp_elem fmt { cursor; outputs; sregs; saved_sp; fallthrough } =
      Format.fprintf fmt
        "{cursor=%a; outputs=%a; sregs=%a; saved_sp=%a; fallthrough=%a}"
        Cursor.pp cursor
        (Format.pp_print_list RegId.pp)
        outputs RegFile.pp sregs Value.pp saved_sp Loc.pp fallthrough
    in
    Format.fprintf fmt "[%a]" (Format.pp_print_list pp_elem) v
end

module State =
  Common_language.HighStateF.Make (Func) (Prog) (CallTarget) (JCall) (JRet)
    (TimeStamp)
    (Value)
    (Store)
    (Cont)
    (Cursor)
    (Stack)
    (World.Environment)