(*
     - SpecificSymbol
       x EndSymbol
       x OperandSymbol
       - PatternlessSymbol
        x EpsilonSymbol
        x VarNodeSymbol
       x StartSymbol
       x Next2Symbol

   *)

type ('triple_t, 'mapped_t, 'oper_artifact) poly_t =
  ('triple_t, 'mapped_t, 'oper_artifact) TypeDef.specific_poly_t

type t = TypeDef.specific_unmapped
type ptr_t = TypeDef.specific_ptr_t

let of_end (v : EndSymbol.t) : ('a, 'b, 'c) poly_t = End v

let of_operand (v : ('a, 'b, 'c) OperandSymbol.poly_t) : ('a, 'b, 'c) poly_t =
  Operand v

let try_operand (v : ('a, 'b, 'c) poly_t) :
    ('a, 'b, 'c) OperandSymbol.poly_t option =
  match v with Operand v -> Some v | _ -> None

let of_epsilon (v : EpsilonSymbol.t) : ('a, 'b, 'c) poly_t =
  Patternless (PatternlessSymbol.of_epsilon v)

let of_varnode (v : VarNodeSymbol.t) : ('a, 'b, 'c) poly_t =
  Patternless (PatternlessSymbol.of_varnode v)

let try_varnode (v : ('a, 'b, 'c) poly_t) : VarNodeSymbol.t option =
  match v with Patternless v -> PatternlessSymbol.try_varnode v | _ -> None

let of_start (v : StartSymbol.t) : ('a, 'b, 'c) poly_t = Start v
let of_next2 (v : Next2Symbol.t) : ('a, 'b, 'c) poly_t = Next2 v

let get_name (symbol : ('a, 'b, 'c) poly_t) : string =
  match symbol with
  | End v -> EndSymbol.get_name v
  | Operand v -> OperandSymbol.get_name v
  | Patternless v -> PatternlessSymbol.get_name v
  | Start v -> StartSymbol.get_name v
  | Next2 v -> Next2Symbol.get_name v

let get_id (symbol : ('a, 'b, 'c) poly_t) : Int32.t =
  match symbol with
  | End v -> EndSymbol.get_id v
  | Operand v -> OperandSymbol.get_id v
  | Patternless v -> PatternlessSymbol.get_id v
  | Start v -> StartSymbol.get_id v
  | Next2 v -> Next2Symbol.get_id v

let get_scopeid (symbol : ('a, 'b, 'c) poly_t) : Int32.t =
  match symbol with
  | End v -> EndSymbol.get_scopeid v
  | Operand v -> OperandSymbol.get_scopeid v
  | Patternless v -> PatternlessSymbol.get_scopeid v
  | Start v -> StartSymbol.get_scopeid v
  | Next2 v -> Next2Symbol.get_scopeid v
