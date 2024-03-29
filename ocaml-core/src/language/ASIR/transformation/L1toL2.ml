let translate_jmp (j : FGIR.Jmp.t_full)
    (alist : (FGIR.Func.t * FGIR.SPFA.Immutable.t) List.t)
    (ga : FGIR.SPFA.Immutable.t) (la : FGIR.AbsState.t) : Jmp.t_full =
  let njmp : Jmp.t =
    match j.jmp with
    | JI v -> JI v
    | JR v -> JR { attr = () }
    | JC { target = Cdirect { target; attr }; fallthrough } ->
        let x =
          List.find_opt
            (fun ((f, _) : FGIR.Func.t * _) -> f.entry = target)
            alist
          |> Option.map (fun ((_, a) : _ * FGIR.SPFA.Immutable.t) -> a.accesses)
        in
        JC
          {
            target = Cdirect { target; attr };
            fallthrough;
            attr =
              {
                reserved_stack =
                  (match x with
                  | Some (Fin s) -> FGIR.AccessD.FinSet.max_elt s
                  | _ -> 0L);
                sp_diff = 8L;
              };
          }
    | JC { target = Cind { target; _ }; fallthrough } ->
        JC
          {
            target = Cind { target };
            fallthrough;
            attr = { reserved_stack = 0L; sp_diff = 8L };
          }
    | JT { target = Cdirect { target; attr } } ->
        let x =
          List.find_opt
            (fun ((f, _) : FGIR.Func.t * _) -> f.entry = target)
            alist
          |> Option.map (fun ((_, a) : _ * FGIR.SPFA.Immutable.t) -> a.accesses)
        in
        JT
          {
            target = Cdirect { target; attr };
            attr =
              {
                reserved_stack =
                  (match x with
                  | Some (Fin s) ->
                      (Int64.mul
                         (Int64.div
                            (Int64.add (FGIR.AccessD.FinSet.max_elt s) 7L)
                            8L))
                        8L
                  | _ -> 0L);
                sp_diff = 8L;
              };
          }
    | JT { target = Cind { target } } ->
        JT
          {
            target = Cind { target };
            attr = { reserved_stack = 0L; sp_diff = 8L };
          }
  in

  { jmp = njmp; loc = j.loc; mnem = j.mnem }

let translate_inst (i : FGIR.Inst.t_full) (ga : FGIR.SPFA.Immutable.t)
    (la : FGIR.AbsState.t) : Inst.t_full =
  let nins : Inst.t =
    match i.ins with
    | IN v -> IN v
    | IA v -> IA v
    | ILS (Load { space; pointer; output }) -> (
        match pointer with
        | Register r -> (
            match FGIR.ARegFile.get la.regs r.id with
            | Flat (SP c) ->
                ISLS (Sload { offset = { value = c; width = 8l }; output })
            | _ -> ILS (Load { space; pointer; output }))
        | _ -> ILS (Load { space; pointer; output }))
    | ILS (Store { space; pointer; value }) -> (
        match pointer with
        | Register r -> (
            match FGIR.ARegFile.get la.regs r.id with
            | Flat (SP c) ->
                ISLS (Sstore { offset = { value = c; width = 8l }; value })
            | _ -> ILS (Store { space; pointer; value }))
        | _ -> ILS (Store { space; pointer; value }))
  in
  { ins = nins; loc = i.loc; mnem = i.mnem }

let translate_block (b : FGIR.Block.t)
    (alist : (FGIR.Func.t * FGIR.SPFA.Immutable.t) List.t)
    (ga : FGIR.SPFA.Immutable.t) : Block.t =
  let astate = FGIR.FSAbsD.AbsLocMapD.find_opt b.loc ga.states.pre_state in
  let body, final_a =
    match astate with
    | Some v ->
        List.fold_left
          (fun (acci, a) i ->
            ( acci @ [ translate_inst i ga a ],
              snd (FGIR.AbsState.post_single_instr i.ins a) ))
          ([], v) b.body
    | None ->
        ( List.map (fun i -> translate_inst i ga FGIR.AbsState.top) b.body,
          FGIR.AbsState.top )
  in
  {
    fLoc = b.fLoc;
    loc = b.loc;
    body;
    jmp = translate_jmp b.jmp alist ga final_a;
  }

let translate_func (f : FGIR.Func.t)
    (alist : (FGIR.Func.t * FGIR.SPFA.Immutable.t) List.t)
    (a : FGIR.SPFA.Immutable.t) : Func.t =
  {
    nameo = f.nameo;
    entry = f.entry;
    blocks = List.map (fun b -> translate_block b alist a) f.blocks;
    boundaries = f.boundaries;
    sp_diff = 8L;
    sp_boundary =
      (match a.accesses with
      | Fin s ->
          ( FGIR.AccessD.FinSet.min_elt s,
            (Int64.mul
               (Int64.div (Int64.add (FGIR.AccessD.FinSet.max_elt s) 7L) 8L))
              8L )
      | _ ->
          [%log
            raise
              (Failure
                 "SPFA.Immutable.analyze returned non-constant sp boundary")]);
  }

let translate_prog (p1 : FGIR.Prog.t) (sp_num : Int32.t) (fp_num : Int32.t) :
    Prog.t =
  let ares =
    List.map
      (fun f -> (f, FGIR.SPFA.Immutable.analyze f sp_num fp_num))
      p1.funcs
  in
  let funcs = List.map (fun (f, r) -> translate_func f ares r) ares in
  {
    sp_num;
    fp_num;
    funcs;
    rom = p1.rom;
    rspec = p1.rspec;
    externs = p1.externs;
  }

let translate_prog_from_spfa (p1 : FGIR.Prog.t)
    (spfa_res : (FGIR.Func.t * FGIR.SPFA.Immutable.t) list) (sp_num : Int32.t)
    (fp_num : Int32.t) : Prog.t =
  let funcs = List.map (fun (f, a) -> translate_func f spfa_res a) spfa_res in
  {
    sp_num;
    fp_num;
    funcs;
    rom = p1.rom;
    rspec = p1.rspec;
    externs = p1.externs;
  }