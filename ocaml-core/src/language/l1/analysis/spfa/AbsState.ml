open StdlibExt
open Basic
open Basic_domain
open Value_domain
include NonRelStateD

let post_single_instr (i : Inst.t) (c : t) : AccessD.t * t =
  match i with
  | Inst.INop -> (AccessD.bottom, c)
  | Inst.Iassignment (a, vn) -> (AccessD.bottom, process_assignment c a vn)
  | Inst.Iload (i0, i1, o) ->
      Logger.debug "load: %a\n" SPVal.pp (eval_varnode c i1);
      (AccessD.log_access (eval_varnode c i1), c)
  | Inst.Istore (i0, i1, i2) ->
      Logger.debug "store: %a\n" SPVal.pp (eval_varnode c i1);
      (AccessD.log_access (eval_varnode c i1), c)

let post_single_jmp (i : Jmp.t) (c : t) (sp_num : int64) : t =
  match i with
  | Jmp.Jcall _ | Jmp.Jcall_ind _ ->
      add
        { id = RegId.Register sp_num; width = 8l }
        (SPVal.add
           (eval_varnode c
              (VarNode.Register { id = RegId.Register sp_num; width = 8l }))
           (SPVal.of_const 8L) 8L)
        c
  | _ -> c

let post_single_block (b : Block.t) (c : t) (sp_num : int64) : AccessD.t * t =
  Block.fold_left
    (fun (acc, c) i ->
      let nacc, c = post_single_instr i.ins c in
      (AccessD.join acc nacc, c))
    (AccessD.bottom, c) b
  |> fun (ac, c) -> (ac, post_single_jmp b.jmp.jmp c sp_num)

let widen = join