open Basic
open Basic_domain
open Value_domain

module Immutable = struct
  type __ = { accesses : AccessD.t; states : FSAbsD.t }

  include
    TupleD.MakeJoinSemiLattice_Record (AccessD) (FSAbsD)
      (struct
        type t = __

        let get_fst x = x.accesses
        let get_snd x = x.states
        let make x y = { accesses = x; states = y }
      end)

  let init (f : L1.Func.t) (sp_num : int64) : t =
    {
      states =
        {
          pre_state =
            FSAbsD.AbsLocMapD.singleton f.entry
              (NonRelStateD.singleton { VarNode.varNode_node = VarNode.Register sp_num; varNode_width = 8l }
                 {
                   SPVal.have_sp = FlatBoolD.Flat true;
                   SPVal.offset = FlatInt64D.Flat 0L;
                 });
          post_state = FSAbsD.AbsLocMapD.empty;
        };
      accesses = AccessD.Fin (Int64SetD.singleton 0L);
    }

  let post_single_block (f : L1.Func.t) (bb : L1.Block.t) (ca : t) (sp_num: int64): t * bool =
    let preds = L1.Func.get_preds f bb in
    let na =
      List.filter_map
        (fun (l : L1.Block.t) ->
          FSAbsD.AbsLocMapD.find_opt l.loc ca.states.pre_state
          |> Option.map (fun a -> (l.loc, a)))
        preds
      |> List.fold_left
           (fun a (l, b) ->
             match a with
             | None -> Some (LocSetD.singleton l, b)
             | Some (lss, a) -> Some (LocSetD.add l lss, AbsState.join a b))
           Option.none
    in
    let na_pre =
      match (na, FSAbsD.AbsLocMapD.find_opt bb.loc ca.states.pre_state) with
      | Some (lss, a), Some b ->
          if LocSetD.exists (fun ls -> fst bb.loc < fst ls) lss then
            AbsState.widen b a
          else AbsState.join b a
      | Some (lss, a), None -> a
      | None, Some a -> a
      | None, None -> raise (Failure "Assertion failed: find_opt")
    in
    let abs_1 : FSAbsD.t =
      {
        pre_state = FSAbsD.AbsLocMapD.add bb.loc na_pre ca.states.pre_state;
        post_state = ca.states.post_state;
      }
    in
    let naccess, np = AbsState.post_single_block bb na_pre sp_num in
    match FSAbsD.AbsLocMapD.find_opt bb.loc ca.states.post_state with
    | Some a ->
        if AbsState.le a np then
          ({ accesses = ca.accesses; states = abs_1 }, false)
        else
          ( {
              accesses = AccessD.join ca.accesses naccess;
              states = FSAbsD.join_single_post abs_1 bb.loc np;
            },
            true )
    | None ->
        ( {
            accesses = AccessD.join ca.accesses naccess;
            states = FSAbsD.join_single_post abs_1 bb.loc np;
          },
          true )

  let post_worklist (f : L1.Func.t) (c : t) (l : Loc.t) (sp_num: int64): t * Loc.t List.t =
    let bb = L1.Func.get_bb f l |> Option.get in
    let na, propagated = post_single_block f bb c sp_num in
    if propagated then (na, L1.Block.succ bb) else (na, [])

  let rec a_fixpoint_worklist (f : L1.Func.t) (c : t) (ls : Loc.t List.t) (sp_num: int64) : t =
    match ls with
    | [] -> c
    | l :: ls ->
        let nc, newLs = post_worklist f c l sp_num in
        a_fixpoint_worklist f nc
          (ls @ List.filter (fun l -> not (List.mem l ls)) newLs) sp_num

  let analyze (f : L1.Func.t) (sp_num : int64) : t =
    a_fixpoint_worklist f (init f sp_num) (f.entry :: []) sp_num
end