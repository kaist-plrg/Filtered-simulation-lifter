let translate_jmp (j : L1.Jmp.t_full)
    (alist : (L1.Func.t * L1.SPFA.Immutable.t) List.t)
    (ga : L1.SPFA.Immutable.t) (la : L1.AbsState.t) : Jmp.t_full =
  let njmp : Jmp.t =
    match j.jmp with
    | Junimplemented -> Junimplemented
    | Jfallthrough l -> Jfallthrough l
    | Jjump l -> Jjump l
    | Jjump_ind { target; candidates; sound } ->
        Jjump_ind { target; candidates; sound }
    | Jcbranch { condition; target_true; target_false } ->
        Jcbranch { condition; target_true; target_false }
    | Jcall { target; fallthrough } ->
        let x =
          List.find_opt (fun ((f, _) : L1.Func.t * _) -> f.entry = target) alist
          |> Option.map (fun ((_, a) : _ * L1.SPFA.Immutable.t) -> a.accesses)
        in
        Jcall
          {
            reserved_stack =
              (match x with
              | Some (Fin s) -> L1.AccessD.FinSet.max_elt s
              | _ -> 0L);
            sp_diff = 8L;
            target;
            fallthrough;
          }
    | Jcall_ind { target; fallthrough } ->
        Jcall_ind { reserved_stack = 0L; sp_diff = 8L; target; fallthrough }
    | Jtailcall target ->
        let x =
          List.find_opt (fun ((f, _) : L1.Func.t * _) -> f.entry = target) alist
          |> Option.map (fun ((_, a) : _ * L1.SPFA.Immutable.t) -> a.accesses)
        in
        Jtailcall
          {
            reserved_stack =
              (match x with
              | Some (Fin s) -> L1.AccessD.FinSet.max_elt s
              | _ -> 0L);
            sp_diff = 8L;
            target;
          }
    | Jtailcall_ind target ->
        Jtailcall_ind { reserved_stack = 0L; sp_diff = 8L; target }
    | Jret vn -> Jret vn
  in

  { jmp = njmp; loc = j.loc; mnem = j.mnem }

let translate_inst (i : L1.Inst.t_full) (ga : L1.SPFA.Immutable.t)
    (la : L1.AbsState.t) : Inst.t_full =
  let nins : Inst.t =
    match i.ins with
    | INop -> INop
    | Iassignment { expr; output } -> Iassignment { expr; output }
    | Iload { space; pointer; output } -> (
        match pointer with
        | Register r -> (
            match L1.AbsState.find_opt r.id la with
            | Some { have_sp = Flat true; offset = Flat c } ->
                Isload { offset = { value = c; width = 8l }; output }
            | _ -> Iload { space; pointer; output })
        | _ -> Iload { space; pointer; output })
    | Istore { space; pointer; value } -> (
        match pointer with
        | Register r -> (
            match L1.AbsState.find_opt r.id la with
            | Some { have_sp = Flat true; offset = Flat c } ->
                Isstore { offset = { value = c; width = 8l }; value }
            | _ -> Istore { space; pointer; value })
        | _ -> Istore { space; pointer; value })
  in
  { ins = nins; loc = i.loc; mnem = i.mnem }

let translate_block (b : L1.Block.t)
    (alist : (L1.Func.t * L1.SPFA.Immutable.t) List.t)
    (ga : L1.SPFA.Immutable.t) : Block.t =
  let astate = L1.FSAbsD.AbsLocMapD.find_opt b.loc ga.states.pre_state in
  let body, final_a =
    match astate with
    | Some v ->
        List.fold_left
          (fun (acci, a) i ->
            ( acci @ [ translate_inst i ga a ],
              snd (L1.AbsState.post_single_instr i.ins a) ))
          ([], v) b.body
    | None ->
        ( List.map (fun i -> translate_inst i ga L1.AbsState.top) b.body,
          L1.AbsState.top )
  in
  {
    fLoc = b.fLoc;
    loc = b.loc;
    body;
    jmp = translate_jmp b.jmp alist ga final_a;
  }

let translate_func (f : L1.Func.t)
    (alist : (L1.Func.t * L1.SPFA.Immutable.t) List.t) (a : L1.SPFA.Immutable.t)
    : Func.t =
  {
    nameo = f.nameo;
    entry = f.entry;
    blocks = List.map (fun b -> translate_block b alist a) f.blocks;
    boundaries = f.boundaries;
    sp_diff = 8L;
    sp_boundary =
      (* MUST FIX: TODO *)
      (match a.accesses with
      | Fin s ->
          ( L1.AccessD.FinSet.min_elt s,
            Int64.add (L1.AccessD.FinSet.max_elt s) 512L )
      | _ ->
          [%log
            raise
              (Failure
                 "SPFA.Immutable.analyze returned non-constant sp boundary")]);
  }

let translate_prog (p1 : L1.Prog.t) (sp_num : Int32.t) : Prog.t =
  let ares =
    List.map (fun f -> (f, L1.SPFA.Immutable.analyze f sp_num)) p1.funcs
  in
  let funcs = List.map (fun (f, r) -> translate_func f ares r) ares in
  { sp_num; funcs; rom = p1.rom; rspec = p1.rspec; externs = p1.externs }

let translate_prog_from_spfa (p1 : L1.Prog.t)
    (spfa_res : (L1.Func.t * L1.SPFA.Immutable.t) list) (sp_num : Int32.t) :
    Prog.t =
  let funcs = List.map (fun (f, a) -> translate_func f spfa_res a) spfa_res in
  { sp_num; funcs; rom = p1.rom; rspec = p1.rspec; externs = p1.externs }
