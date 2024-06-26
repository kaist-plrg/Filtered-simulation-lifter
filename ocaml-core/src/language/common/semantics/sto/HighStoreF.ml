module Make
    (Prog : sig
      type t

      val sp_num : t -> Int32.t
    end)
    (Const : ConstF.S)
    (VarNode : VarNodeF.S with module Const = Const)
    (Pointer : PointerF.S)
    (Value : ValueF.S with module Const = Const and module Pointer = Pointer)
    (SPtoVal : sig
      type t = Value.t

      val sp : SPVal.t -> Value.t
    end)
    (Action : sig
      type t

      val of_assign : RegId.t_full -> Value.t -> t
      val of_load : RegId.t_full -> Value.t -> Value.t -> t
      val of_store : Value.t -> Value.t -> t
      val nop : t

      val to_either4 :
        t ->
        ( RegId.t_full * Value.t,
          RegId.t_full * Value.t * Value.t,
          Value.t * Value.t,
          Unit.t )
        Either4.t
    end)
    (HighCursor : sig
      type t

      val get_func_loc : t -> Loc.t
      val get_timestamp : t -> Int64.t
    end)
    (RegFile : sig
      type t

      val pp : Format.formatter -> t -> unit
      val add_reg : t -> RegId.t_full -> Value.t -> t
      val get_reg : t -> RegId.t_full -> Value.t
    end)
    (Memory : MemoryF.S with module Value = Value and module Pointer = Pointer)
    (Frame : sig
      type t

      val empty : Int64.t -> Int64.t -> t
      val store_mem : t -> Int64.t -> Value.t -> (t, String.t) Result.t
    end) =
struct
  type t = { regs : RegFile.t; mem : Memory.t }

  let pp fmt v = Format.fprintf fmt "@[<1>regs: %a@]" RegFile.pp v.regs

  let add_reg (s : t) (r : RegId.t_full) (v : Value.t) : t =
    { s with regs = RegFile.add_reg s.regs r v }

  let get_reg (s : t) (r : RegId.t_full) : Value.t = RegFile.get_reg s.regs r

  let load_mem (s : t) (v : Value.t) (width : Int32.t) :
      (Value.t, String.t) Result.t =
    let* ptv = Value.try_pointer v in
    Memory.load_mem s.mem ptv width |> Result.ok

  let load_string (s : t) (v : Value.t) : (String.t, String.t) Result.t =
    let* ptv = Value.try_pointer v in
    Memory.load_string s.mem ptv

  let load_bytes (s : t) (v : Value.t) (width : Int32.t) :
      (String.t, String.t) Result.t =
    let* ptv = Value.try_pointer v in
    Memory.load_bytes s.mem ptv width

  let store_mem (s : t) (v : Value.t) (e : Value.t) : (t, String.t) Result.t =
    let* ptv = Value.try_pointer v in
    let* mem = Memory.store_mem s.mem ptv e in
    { s with mem } |> Result.ok

  let store_bytes (s : t) (v : Value.t) (e : String.t) : (t, String.t) Result.t
      =
    let* ptv = Value.try_pointer v in
    let* mem = Memory.store_bytes s.mem ptv e in
    { s with mem } |> Result.ok

  let eval_vn (s : t) (vn : VarNode.t) : (Value.t, String.t) Result.t =
    match vn with
    | Register r -> get_reg s r |> Result.ok
    | Const v -> v |> Value.of_const |> Result.ok
    | Ram v -> load_mem s (v |> Value.of_const) (Const.get_width v)

  let eval_vn_list (s : t) (vnl : VarNode.t List.t) :
      (Value.t List.t, String.t) Result.t =
    List.fold_right
      (fun vn acc ->
        match acc with
        | Ok acc ->
            let* v = eval_vn s vn in
            Ok (v :: acc)
        | Error e -> Error e)
      vnl (Ok [])

  let eval_assignment (s : t) (a : VarNode.t AssignableF.poly_t)
      (outwidth : Int32.t) : (Value.t, String.t) Result.t =
    match a with
    | Avar vn -> eval_vn s vn
    | Auop (u, vn) ->
        let* v = eval_vn s vn in
        Value.eval_uop u v outwidth
    | Abop (Bop.Bint_xor, lv, rv) when VarNode.compare lv rv = 0 ->
        Value.zero outwidth |> Result.ok
    | Abop (Bop.Bint_sub, lv, rv) when VarNode.compare lv rv = 0 ->
        Value.zero outwidth |> Result.ok
    | Abop (b, lv, rv) ->
        let* lv = eval_vn s lv in
        let* rv = eval_vn s rv in
        Value.eval_bop b lv rv outwidth

  let step_IA (s : t)
      ({ expr; output } : VarNode.t AssignableF.poly_t IAssignment.poly_t) :
      (Action.t, String.t) Result.t =
    let* v = eval_assignment s expr output.width in
    Action.of_assign output v |> Result.ok

  let step_ILS (s : t) (v : VarNode.t ILoadStore.poly_t) :
      (Action.t, String.t) Result.t =
    match v with
    | Load { pointer; output; _ } ->
        let* addrv = eval_vn s pointer in
        let* lv = load_mem s addrv output.width in
        [%log debug "Loading %a from %a" Value.pp lv Value.pp addrv];
        Action.of_load output addrv lv |> Result.ok
    | Store { pointer; value; _ } ->
        let* addrv = eval_vn s pointer in
        let* sv = eval_vn s value in
        [%log debug "Storing %a at %a" Value.pp sv Value.pp addrv];
        Action.of_store addrv sv |> Result.ok

  let step_ISLS (s : t) (curr : HighCursor.t) (v : VarNode.t ISLoadStore.poly_t)
      : (Action.t, String.t) Result.t =
    match v with
    | Sload { offset; output } ->
        let addrv =
          SPtoVal.sp
            {
              func = HighCursor.get_func_loc curr;
              timestamp = HighCursor.get_timestamp curr;
              multiplier = 1L;
              offset;
            }
        in
        let* lv = load_mem s addrv output.width in
        [%log debug "Loading %a from %a" Value.pp lv Value.pp addrv];
        Action.of_load output addrv lv |> Result.ok
    | Sstore { offset; value } ->
        let addrv =
          SPtoVal.sp
            {
              func = HighCursor.get_func_loc curr;
              timestamp = HighCursor.get_timestamp curr;
              multiplier = 1L;
              offset;
            }
        in
        let* sv = eval_vn s value in
        [%log debug "Storing %a at %a" Value.pp sv Value.pp addrv];
        Action.of_store addrv sv |> Result.ok

  let step_IN (s : t) (_ : INop.t) : (Action.t, String.t) Result.t =
    Ok Action.nop

  let action_assign (s : t) (r : RegId.t_full) (v : Value.t) :
      (t, String.t) Result.t =
    add_reg s r v |> Result.ok

  let action_load (s : t) (r : RegId.t_full) (p : Value.t) (v : Value.t) :
      (t, String.t) Result.t =
    add_reg s r v |> Result.ok

  let action_store (s : t) (p : Value.t) (v : Value.t) : (t, String.t) Result.t
      =
    store_mem s p v

  let action_nop (s : t) : (t, String.t) Result.t = Ok s

  let action (s : t) (a : Action.t) =
    match Action.to_either4 a with
    | First (r, v) -> action_assign s r v
    | Second (r, p, v) -> action_load s r p v
    | Third (p, v) -> action_store s p v
    | Fourth () -> action_nop s

  let build_arg (s : t) (tagv : Interop.tag) (v : Value.t) :
      (Interop.t, String.t) Result.t =
    match tagv with
    | TString ->
        let* v = load_string s v in
        Interop.VString v |> Result.ok
    | T8 -> (
        match Value.try_num v with
        | Ok value ->
            let* value = NumericValue.value_64 value in
            Interop.V8 (Char.chr (Int64.to_int value)) |> Result.ok
        | _ -> Error "Not a number")
    | T16 -> (
        match Value.try_num v with
        | Ok value ->
            let* value = NumericValue.value_64 value in
            Interop.V16 (Int64.to_int32 value) |> Result.ok
        | _ -> Error "Not a number")
    | T32 -> (
        match Value.try_num v with
        | Ok value ->
            let* value = NumericValue.value_64 value in

            Interop.V32 (Int64.to_int32 value) |> Result.ok
        | _ -> Error "Not a number")
    | T64 -> (
        match Value.try_num v with
        | Ok value ->
            let* value = NumericValue.value_64 value in
            Interop.V64 value |> Result.ok
        | _ ->
            Interop.V64
              (Foreign.foreign "strdup"
                 (Ctypes_static.( @-> ) Ctypes.string
                    (Ctypes.returning Ctypes_static.int64_t))
                 "[null]")
            |> Result.ok)
    | TBuffer n ->
        let* v = load_bytes s v (Int64.to_int32 n) in
        Interop.VBuffer (v |> String.to_bytes) |> Result.ok
    | TIBuffer n ->
        let* v = load_bytes s v (Int64.to_int32 n) in
        Interop.VIBuffer v |> Result.ok
    | _ -> "Not supported" |> Result.error

  let build_ret (s : t) (v : Interop.t) : (t, String.t) Result.t =
    match v with
    | V8 c ->
        add_reg s
          { id = RegId.Register 0l; offset = 0l; width = 8l }
          (Value.of_num (NumericValue.of_int64 (Int64.of_int (Char.code c)) 8l))
        |> Result.ok
    | V16 i ->
        add_reg s
          { id = RegId.Register 0l; offset = 0l; width = 8l }
          (Value.of_num (NumericValue.of_int64 (Int64.of_int32 i) 8l))
        |> Result.ok
    | V32 i ->
        add_reg s
          { id = RegId.Register 0l; offset = 0l; width = 8l }
          (Value.of_num (NumericValue.of_int64 (Int64.of_int32 i) 8l))
        |> Result.ok
    | V64 i ->
        add_reg s
          { id = RegId.Register 0l; offset = 0l; width = 8l }
          (Value.of_num (NumericValue.of_int64 i 8l))
        |> Result.ok
    | _ -> "Unsupported return type" |> Result.error

  let build_args (s : t) (fsig : Interop.func_sig) :
      ((Value.t * Interop.t) list, String.t) Result.t =
    if List.length fsig.params > 6 then
      [%log fatal "At most 6 argument is supported for external functions"];
    let reg_list = [ 56l; 48l; 16l; 8l; 128l; 136l ] in
    let val_list =
      List.map
        (fun r -> get_reg s { id = RegId.Register r; offset = 0l; width = 8l })
        reg_list
    in
    let* nondep_tags =
      List.fold_right
        (fun (tag : Interop.tag) (acc : (Interop.tag List.t, String.t) Result.t) ->
          let* ntag =
            match tag with
            | TBuffer_dep n ->
                let* k =
                  build_arg s (List.nth fsig.params n) (List.nth val_list n)
                in
                Interop.TBuffer (Interop.extract_64 k) |> Result.ok
            | TIBuffer_dep n ->
                let* k =
                  build_arg s (List.nth fsig.params n) (List.nth val_list n)
                in
                Interop.TIBuffer (Interop.extract_64 k) |> Result.ok
            | _ -> tag |> Result.ok
          in
          match acc with Ok l -> Ok (ntag :: l) | Error e -> Error e)
        fsig.params (Ok [])
    in
    try
      let ndt =
        List.combine nondep_tags (List.take (List.length nondep_tags) val_list)
      in
      List.fold_right
        (fun (t, v) acc ->
          let* k = build_arg s t v in
          match acc with Ok acc -> Ok ((v, k) :: acc) | Error e -> Error e)
        ndt (Ok [])
    with Invalid_argument _ ->
      "Mismatched number of arguments for external functions" |> Result.error

  let build_side (s : t) (value : Value.t) (t : Interop.t) :
      (t, String.t) Result.t =
    match t with
    | Interop.VBuffer v ->
        [%log debug "Storing extern_val at %a" Value.pp value];
        store_bytes s value (Bytes.to_string v)
    | _ -> Error "Unreachable"

  let build_sides (s : t) (values : Value.t List.t)
      (sides : (Int.t * Interop.t) List.t) : (t, String.t) Result.t =
    List.fold_left
      (fun s (i, t) ->
        Result.bind s (fun s -> build_side s (List.nth values i) t))
      (Ok s) sides

  let get_sp_curr (s : t) (p : Prog.t) : Value.t =
    get_reg s { id = RegId.Register (Prog.sp_num p); offset = 0l; width = 8l }

  let build_local_frame (s : t) (p : Prog.t) (bnd : Int64.t * Int64.t)
      (copydepth : Int64.t) =
    let sp_curr = get_sp_curr s p in
    let* passing_vals =
      List.fold_left
        (fun acc (i, x) ->
          match acc with
          | Error _ -> acc
          | Ok acc ->
              let* addr = x in
              let* v = load_mem s addr 8l in
              Ok ((i, v) :: acc))
        (Ok [])
        (Int64.div (Int64.add copydepth 7L) 8L
        |> Int64.to_int
        |> Fun.flip List.init (fun x ->
               ( Int64.of_int (x * 8),
                 Value.eval_bop Bop.Bint_add sp_curr
                   (Value.of_num
                      (NumericValue.of_int64 (Int64.of_int (x * 8)) 8l))
                   8l )))
    in
    List.fold_left
      (fun acc (i, j) -> Result.bind acc (fun acc -> Frame.store_mem acc i j))
      (Frame.empty (fst bnd) (snd bnd) |> Result.ok)
      passing_vals

  let build_saved_sp (s : t) (p : Prog.t) (spdiff : Int64.t) :
      (Value.t, String.t) Result.t =
    let sp_curr = get_sp_curr s p in
    Value.eval_bop Bop.Bint_add sp_curr
      (Value.of_num (NumericValue.of_int64 spdiff 8l))
      8l

  let sp_extern (p : Prog.t) : RegId.t_full =
    { id = RegId.Register (Prog.sp_num p); offset = 0l; width = 8l }

  let add_sp_extern (s : t) (p : Prog.t) : (Value.t, String.t) Result.t =
    Value.eval_bop Bop.Bint_add
      (get_reg s (sp_extern p))
      (Value.of_num (NumericValue.of_int64 8L 8l))
      8l
end
