open StdlibExt
open Basic
open Basic_collection
open Common_language

let ( let* ) = Result.bind

let eval_vn (vn : VarNode.t) (s : State.t) : Value.t =
  match vn with
  | Register r -> RegFile.get_reg s.regs r
  | Const v -> Num (NumericValue.of_int64 v.value v.width)
  | Ram v ->
      Store.load_mem s.sto (Num (NumericValue.of_int64 v.value 8l)) v.width
      |> Result.get_ok

let eval_assignment (a : Assignable.t) (s : State.t) (outwidth : Int32.t) :
    (Value.t, String.t) Result.t =
  match a with
  | Avar vn -> Ok (eval_vn vn s)
  | Auop (u, vn) -> Value.eval_uop u (eval_vn vn s) outwidth
  | Abop (Bop.Bint_xor, lv, rv) when VarNode.compare lv rv = 0 ->
      Ok (Value.zero outwidth)
  | Abop (Bop.Bint_sub, lv, rv) when VarNode.compare lv rv = 0 ->
      Ok (Value.zero outwidth)
  | Abop (b, lv, rv) -> Value.eval_bop b (eval_vn lv s) (eval_vn rv s) outwidth

let build_arg (s : State.t) (tagv : Common_language.Interop.tag) (v : Value.t) :
    Common_language.Interop.t =
  match tagv with
  | TString -> VString (Store.load_string s.sto v |> Result.get_ok)
  | T8 ->
      V8
        (Char.chr
           (match v with
           | Num value -> Int64.to_int (NumericValue.value_64 value)
           | _ -> [%log fatal "Not a number"]))
  | T16 ->
      V16
        (Int64.to_int32
           (match v with
           | Num value -> NumericValue.value_64 value
           | _ -> [%log fatal "Not a number"]))
  | T32 ->
      V32
        (Int64.to_int32
           (match v with
           | Num value -> NumericValue.value_64 value
           | _ -> [%log fatal "Not a number"]))
  | T64 ->
      V64
        (match v with
        | Num value -> NumericValue.value_64 value
        | _ ->
            Foreign.foreign "strdup"
              (Ctypes_static.( @-> ) Ctypes.string
                 (Ctypes.returning Ctypes_static.int64_t))
              "[null]")
  | TBuffer n ->
      let v = Store.load_bytes s.sto v (Int64.to_int32 n) |> Result.get_ok in
      VBuffer (v |> String.to_bytes)
  | TIBuffer n ->
      let v = Store.load_bytes s.sto v (Int64.to_int32 n) |> Result.get_ok in
      VIBuffer v
  | _ -> [%log fatal "Not supported"]

let build_ret (s : State.t) (v : Common_language.Interop.t) : State.t =
  match v with
  | V8 c ->
      {
        s with
        regs =
          RegFile.add_reg s.regs
            { id = RegId.Register 0l; offset = 0l; width = 8l }
            (Value.Num (NumericValue.of_int64 (Int64.of_int (Char.code c)) 8l));
      }
  | V16 i ->
      {
        s with
        regs =
          RegFile.add_reg s.regs
            { id = RegId.Register 0l; offset = 0l; width = 8l }
            (Value.Num (NumericValue.of_int64 (Int64.of_int32 i) 8l));
      }
  | V32 i ->
      {
        s with
        regs =
          RegFile.add_reg s.regs
            { id = RegId.Register 0l; offset = 0l; width = 8l }
            (Value.Num (NumericValue.of_int64 (Int64.of_int32 i) 8l));
      }
  | V64 i ->
      {
        s with
        regs =
          RegFile.add_reg s.regs
            { id = RegId.Register 0l; offset = 0l; width = 8l }
            (Value.Num (NumericValue.of_int64 i 8l));
      }
  | _ -> [%log fatal "Unsupported return type"]

let build_args (s : State.t) (fsig : Interop.func_sig) :
    (Value.t * Interop.t) list =
  if List.length fsig.params > 6 then
    [%log fatal "At most 6 argument is supported for external functions"];
  let reg_list = [ 56l; 48l; 16l; 8l; 128l; 136l ] in
  let val_list =
    List.map
      (fun r ->
        RegFile.get_reg s.regs
          { id = RegId.Register r; offset = 0l; width = 8l })
      reg_list
  in
  (let nondep_tags =
     List.map
       (fun (tag : Interop.tag) ->
         match tag with
         | TBuffer_dep n ->
             let k =
               Interop.extract_64
                 (build_arg s (List.nth fsig.params n) (List.nth val_list n))
             in
             Interop.TBuffer k
         | TIBuffer_dep n ->
             let k =
               Interop.extract_64
                 (build_arg s (List.nth fsig.params n) (List.nth val_list n))
             in
             Interop.TIBuffer k
         | _ -> tag)
       fsig.params
   in
   try
     List.combine nondep_tags (ListExt.take (List.length nondep_tags) val_list)
   with Invalid_argument _ ->
     [%log fatal "Mismatched number of arguments for external functions"])
  |> List.map (fun (t, v) -> (v, build_arg s t v))

let build_side (s : State.t) (value : Value.t) (t : Interop.t) :
    (State.t, String.t) Result.t =
  match t with
  | Interop.VBuffer v ->
      [%log debug "Storing extern_val at %a" Value.pp value];
      let* sto = Store.store_bytes s.sto value (Bytes.to_string v) in
      Ok { s with sto }
  | _ -> Error "Unreachable"

let build_sides (s : State.t) (values : Value.t List.t)
    (sides : (Int.t * Interop.t) List.t) : (State.t, String.t) Result.t =
  List.fold_left
    (fun s (i, t) ->
      Result.bind s (fun s -> build_side s (List.nth values i) t))
    (Ok s) sides

let step_ins (p : Prog.t) (ins : Inst.t) (s : State.t) (func : Loc.t * Int64.t)
    : (State.t, String.t) Result.t =
  match ins with
  | Iassignment { expr; output } ->
      let* v = eval_assignment expr s output.width in
      Ok { s with regs = RegFile.add_reg s.regs output v }
  | Iload { pointer; output; _ } ->
      let addrv = eval_vn pointer s in
      let* lv = Store.load_mem s.sto addrv output.width in
      [%log debug "Loading %a from %a" Value.pp lv Value.pp addrv];
      Ok { s with regs = RegFile.add_reg s.regs output lv }
  | Istore { pointer; value; _ } ->
      let addrv = eval_vn pointer s in
      let sv = eval_vn value s in
      [%log debug "Storing %a at %a" Value.pp sv Value.pp addrv];
      let* sto' = Store.store_mem s.sto addrv sv in
      Ok { s with sto = sto' }
  | Isload { offset; output } ->
      let addrv =
        Value.sp
          { func = fst func; timestamp = snd func; offset = offset.value }
      in
      let* lv = Store.load_mem s.sto addrv output.width in
      [%log debug "Loading %a from %a" Value.pp lv Value.pp addrv];
      Ok { s with regs = RegFile.add_reg s.regs output lv }
  | Isstore { offset; value } ->
      let addrv =
        Value.sp
          { func = fst func; timestamp = snd func; offset = offset.value }
      in
      let sv = eval_vn value s in
      [%log debug "Storing %a at %a" Value.pp sv Value.pp addrv];
      let* sto' = Store.store_mem s.sto addrv sv in
      Ok { s with sto = sto' }
  | INop -> Ok s

let step_call_extern (p : Prog.t) (spdiff : Int64.t) (name : String.t)
    (retn : Loc.t) (s : State.t) =
  [%log debug "Calling %s" name];
  let* fsig, _ =
    StringMap.find_opt name World.Environment.signature_map
    |> Option.to_result ~none:(Format.asprintf "No external function %s" name)
  in
  let values, args = build_args s fsig |> List.split in
  [%log
    debug "Call values: %a"
      (Format.pp_print_list ~pp_sep:Format.pp_print_space Value.pp)
      values];
  [%log
    debug "Call args: %a"
      (Format.pp_print_list ~pp_sep:Format.pp_print_space Interop.pp)
      args];
  let sides, retv = World.Environment.request_call name args in
  [%log
    debug "Side values: %a"
      (Format.pp_print_list ~pp_sep:Format.pp_print_space (fun fmt (i, v) ->
           Format.fprintf fmt "%d: %a" i Interop.pp v))
      sides];
  let sp_curr =
    RegFile.get_reg s.regs { id = RegId.Register 32l; offset = 0l; width = 8l }
  in
  let* sp_saved =
    Value.eval_bop Bop.Bint_add sp_curr
      (Num (NumericValue.of_int64 spdiff 8l))
      8l
  in

  let* ncont = Cont.of_block_loc p (fst s.func) retn in
  let* s_side = build_sides s values sides in
  Ok
    (build_ret
       {
         s_side with
         regs =
           RegFile.add_reg s_side.regs
             { id = RegId.Register 32l; offset = 0l; width = 8l }
             sp_saved;
         cont = ncont;
         stack = s_side.stack;
       }
       retv)

let get_func_from (p : Prog.t) (target : Loc.t) : (Func.t, String.t) Result.t =
  Prog.get_func_opt p target
  |> Option.to_result
       ~none:(Format.asprintf "jcall: not found function %a" Loc.pp target)

let get_current_function (p : Prog.t) (s : State.t) :
    (Func.t, String.t) Result.t =
  get_func_from p (fst s.func)

let get_sp_curr (s : State.t) (regid : Int32.t) : Value.t =
  RegFile.get_reg s.regs { id = RegId.Register 32l; offset = 0l; width = 8l }

let build_local_frame (s : State.t) (copydepth : Int64.t) =
  let sp_curr = get_sp_curr s 32l in
  let* passing_vals =
    List.fold_left
      (fun acc (i, x) ->
        match acc with
        | Error _ -> acc
        | Ok acc ->
            let* addr = x in
            let* v = Store.load_mem s.sto addr 8l in
            Ok ((i, v) :: acc))
      (Ok [])
      (Int64.div copydepth 8L |> Int64.succ |> Int64.to_int
      |> Fun.flip List.init (fun x ->
             ( Int64.of_int (x * 8),
               Value.eval_bop Bop.Bint_add sp_curr
                 (Num (NumericValue.of_int64 (Int64.of_int (x * 8)) 8l))
                 8l )))
  in
  Ok
    (List.fold_left
       (fun acc (i, j) -> Frame.store_mem acc i j)
       Frame.empty passing_vals)

let get_sp_saved (s : State.t) (spdiff : Int64.t) : (Value.t, String.t) Result.t
    =
  let sp_curr = get_sp_curr s 32l in
  Value.eval_bop Bop.Bint_add sp_curr (Num (NumericValue.of_int64 spdiff 8l)) 8l

let step_call (p : Prog.t) (copydepth : Int64.t) (spdiff : Int64.t)
    (outputs : RegId.t List.t) (inputs : VarNode.t List.t) (calln : Loc.t)
    (retn : Loc.t) (s : State.t) : (State.t, String.t) Result.t =
  match AddrMap.find_opt (Loc.to_addr calln) p.externs with
  | None ->
      let* currf = get_current_function p s in
      let* f = get_func_from p calln in
      let* _ =
        if f.sp_diff = spdiff then Ok () else Error "jcall: spdiff not match"
      in
      let* ncont = Cont.of_func_entry_loc p calln in
      let* nlocal = build_local_frame s copydepth in
      let* sp_saved = get_sp_saved s spdiff in
      Ok
        {
          State.timestamp = Int64Ext.succ s.timestamp;
          cont = ncont;
          stack = (s.func, outputs, s.regs, sp_saved, retn) :: s.stack;
          regs =
            RegFile.add_reg
              (List.fold_left
                 (fun r (i, v) ->
                   RegFile.add_reg r
                     { id = i; offset = 0l; width = 8l }
                     (eval_vn v s))
                 (RegFile.of_seq Seq.empty)
                 (try List.combine f.inputs inputs
                  with Invalid_argument _ ->
                    [%log
                      fatal
                        "Mismatched number of arguments for call inputs,\n\
                        \                      %d for %s and %d for call \
                         instruction"
                        (List.length f.inputs)
                        (f.nameo |> Option.value ~default:"noname")
                        (List.length inputs)]))
              { id = RegId.Register 32l; offset = 0l; width = 8l }
              (Value.sp
                 {
                   func = calln;
                   timestamp = Int64Ext.succ s.timestamp;
                   offset = 0L;
                 });
          func = (calln, Int64Ext.succ s.timestamp);
          sto =
            {
              s.sto with
              local =
                s.sto.local
                |> LocalMemory.add
                     (calln, Int64Ext.succ s.timestamp)
                     nlocal;
            };
        }
  | Some name -> step_call_extern p spdiff name retn s

let step_call_ind (p : Prog.t) (copydepth : Int64.t) (spdiff : Int64.t)
    (calln : Loc.t) (retn : Loc.t) (s : State.t) : (State.t, String.t) Result.t
    =
  match AddrMap.find_opt (Loc.to_addr calln) p.externs with
  | None ->
      let* currf = get_current_function p s in
      let* f = get_func_from p calln in
      let* _ =
        if f.sp_diff = spdiff then Ok ()
        else Error "jcall_ind: spdiff not match"
      in
      (* TODO: think ind copydepth
         let* _ =
           if snd f.sp_boundary <= copydepth then Ok ()
           else Error "jcall_ind: copydepth not match"
         in
      *)
      let* ncont = Cont.of_func_entry_loc p calln in
      let* nlocal = build_local_frame s (snd f.sp_boundary) in
      let* sp_saved = get_sp_saved s spdiff in
      Ok
        {
          State.timestamp = Int64Ext.succ s.timestamp;
          cont = ncont;
          stack = (s.func, f.outputs, s.regs, sp_saved, retn) :: s.stack;
          regs =
            RegFile.add_reg
              (List.fold_left
                 (fun r i ->
                   RegFile.add_reg r
                     { id = i; offset = 0l; width = 8l }
                     (RegFile.get_reg s.regs
                        { id = i; offset = 0l; width = 8l }))
                 (RegFile.of_seq Seq.empty) f.inputs)
              { id = RegId.Register 32l; offset = 0l; width = 8l }
              (Value.sp
                 {
                   func = calln;
                   timestamp = Int64Ext.succ s.timestamp;
                   offset = 0L;
                 });
          func = (calln, Int64Ext.succ s.timestamp);
          sto =
            {
              s.sto with
              local =
                s.sto.local
                |> LocalMemory.add
                     (calln, Int64Ext.succ s.timestamp)
                     nlocal;
            };
        }
  | Some name -> step_call_extern p spdiff name retn s

let step_jmp (p : Prog.t) (jmp : Jmp.t_full) (s : State.t) :
    (State.t, String.t) Result.t =
  match jmp.jmp with
  | Jjump l ->
      let* ncont = Cont.of_block_loc p (fst s.func) l in
      Ok { s with cont = ncont }
  | Jfallthrough l ->
      let* ncont = Cont.of_block_loc p (fst s.func) l in
      Ok { s with cont = ncont }
  | Jjump_ind { target; candidates; _ } ->
      let* loc = Value.try_loc (eval_vn target s) in
      if LocSet.mem loc candidates then
        let* ncont = Cont.of_block_loc p (fst s.func) loc in
        Ok { s with cont = ncont }
      else Error "jump_ind: Not a valid jump"
  | Jcbranch { condition; target_true; target_false } ->
      let v = eval_vn condition s in
      [%log debug "Jcbranch %a" Value.pp v];
      let* iz = Value.try_isZero v in
      if iz then
        let* ncont = Cont.of_block_loc p (fst s.func) target_false in
        Ok { s with cont = ncont }
      else
        let* ncont = Cont.of_block_loc p (fst s.func) target_true in
        Ok { s with cont = ncont }
  | Jcall { reserved_stack; sp_diff; outputs; inputs; target; fallthrough } ->
      step_call p reserved_stack sp_diff outputs inputs target fallthrough s
  | Jcall_ind { reserved_stack; sp_diff; target; fallthrough } ->
      let* calln = Value.try_loc (eval_vn target s) in
      step_call_ind p reserved_stack sp_diff calln fallthrough s
  | Jret values -> (
      match s.stack with
      | [] -> Error (Format.asprintf "Empty stack")
      | (calln, outputs, regs', sp_saved, retn') :: stack' ->
          let* ncont = Cont.of_block_loc p (fst calln) retn' in
          let values =
            List.fold_left
              (fun acc o ->
                let v = eval_vn o s in
                v :: acc)
              [] values
            |> List.rev
          in
          let output_values =
            try List.combine outputs values
            with Invalid_argument _ ->
              [%log fatal "Mismatched number of outputs for call outputs"]
          in
          Ok
            {
              State.cont = ncont;
              timestamp = s.timestamp;
              stack = stack';
              func = calln;
              sto = s.sto;
              regs =
                RegFile.add_reg
                  (List.fold_left
                     (fun r (o, v) ->
                       RegFile.add_reg r { id = o; offset = 0l; width = 8l } v)
                     regs' output_values)
                  { id = RegId.Register 32l; offset = 0l; width = 8l }
                  sp_saved;
            })
  | Jtailcall _ | Jtailcall_ind _ | Junimplemented -> Error "unimplemented jump"

let step (p : Prog.t) (s : State.t) : (State.t, String.t) Result.t =
  match s.cont with
  | { remaining = []; jmp } ->
      step_jmp p jmp s
      |> Result.map_error (fun e -> Format.asprintf "%a: %s" Loc.pp jmp.loc e)
  | { remaining = i :: []; jmp } ->
      let* s' =
        step_ins p i.ins s s.func
        |> Result.map_error (fun e -> Format.asprintf "%a: %s" Loc.pp i.loc e)
      in
      step_jmp p jmp s'
      |> Result.map_error (fun e -> Format.asprintf "%a: %s" Loc.pp jmp.loc e)
  | { remaining = i :: res; jmp } ->
      let* s' =
        step_ins p i.ins s s.func
        |> Result.map_error (fun e -> Format.asprintf "%a: %s" Loc.pp i.loc e)
      in
      Ok { s' with cont = { remaining = res; jmp } }

let rec interp (p : Prog.t) (s : State.t) : (State.t, String.t) Result.t =
  let s' = step p s in
  match s' with
  | Error _ -> s'
  | Ok s' ->
      [%log debug "%a" State.pp s'];
      interp p s'
