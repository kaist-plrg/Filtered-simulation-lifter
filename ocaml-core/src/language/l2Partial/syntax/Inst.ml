open Basic
open Common_language

module Inner = struct
  type t =
    | Iload of { space : VarNode.t; pointer : VarNode.t; output : RegId.t_full }
    | Istore of { space : VarNode.t; pointer : VarNode.t; value : VarNode.t }
    | Isload of { offset : Const.t; output : RegId.t_full }
    | Isstore of { offset : Const.t; value : VarNode.t }
    | Iassignment of { expr : Assignable.t; output : RegId.t_full }
    | INop

  let pp (fmt : Format.formatter) (p : t) =
    match p with
    | Iload { space; pointer; output } ->
        Format.fprintf fmt "%a = *[%a]%a;" RegId.pp_full output VarNode.pp space
          VarNode.pp pointer
    | Istore { space; pointer; value } ->
        Format.fprintf fmt "*[%a]%a = %a;" VarNode.pp space VarNode.pp pointer
          VarNode.pp value
    | Isload { offset; output } ->
        Format.fprintf fmt "%a = stack[%a];" RegId.pp_full output Const.pp
          offset
    | Isstore { offset; value } ->
        Format.fprintf fmt "stack[%a] = %a;" Const.pp offset VarNode.pp value
    | Iassignment { expr; output } ->
        Format.fprintf fmt "%a = %a;" RegId.pp_full output Assignable.pp expr
    | INop -> Format.fprintf fmt "nop;"

  let is_nop ins = match ins with INop -> true | _ -> false
end

include Inner
include InstFullF.Make (Inner)
