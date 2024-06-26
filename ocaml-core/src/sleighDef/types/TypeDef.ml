type printpiece = Str of String.t | OperInd of Int32.t

type 'operand_t constructor_poly_t = {
  parentId : SubtablePtr.t;
  minimumlength : Int32.t;
  firstWhitespace : Int32.t;
  flowthruIndex : Int32.t Option.t;
  operandIds : 'operand_t List.t;
  printpieces : printpiece List.t;
  context : ContextChange.t List.t;
  tmpl : ConstructTpl.t Option.t;
  namedtmpl : ConstructTpl.t Int32Map.t;
}

type constructor_ptr_t = OperandPtr.t constructor_poly_t

(*
   Symbol
    - TripleSymbol
     - FamilySymbol
      - ValueSymbol
       x PureValueSymbol
       x ContextSymbol
       x NameSymbol
       x ValueMapSymbol
       x VarNodeListSymbol
     - SpecificSymbol
       x EndSymbol
       x OperandSymbol
       - PatternlessSymbol
        x EpsilonSymbol
        x VarNodeSymbol
       x StartSymbol
       x Next2Symbol
     x SubtableSymbol
    x UserOpSymbol
*)

type user_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  index : Int32.t;
}

type purevalue_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  pattern : PatternExpression.t;
}

type context_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  pattern : PatternExpression.t;
  varNodeId : VarNodePtr.t;
  low : Int32.t;
  high : Int32.t;
  flow : Bool.t;
}

type name_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  pattern : PatternExpression.t;
  names : String.t List.t;
}

type valuemap_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  pattern : PatternExpression.t;
  values : Int32.t List.t;
}

type 'varnode_t varnodelist_poly_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  pattern : PatternExpression.t;
  varNodeIds : 'varnode_t Option.t List.t;
}

type varnodelist_ptr_t = VarNodePtr.t varnodelist_poly_t

type 'varnode_t value_poly_t =
  | PureValue of purevalue_t
  | Context of context_t
  | Name of name_t
  | ValueMap of valuemap_t
  | VarNodeList of 'varnode_t varnodelist_poly_t

type value_ptr_t = VarNodePtr.t value_poly_t
type 'varnode_t family_poly_t = Value of 'varnode_t value_poly_t
type family_ptr_t = VarNodePtr.t family_poly_t

type end_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  const_space : AddrSpace.t;
  patexp : PatternExpression.t;
}

type ('tuple_t, 'mapped_t) operand_elem =
  | OTriple of ('tuple_t, 'mapped_t) Either.t
  | ODefExp of OperandExpression.t

type operand_ptr_elem = (TuplePtr.t, SubtablePtr.t) operand_elem

type ('tuple_t, 'mapped_t, 'oper_artifact) operand_poly_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  operand_value : ('tuple_t, 'mapped_t) operand_elem;
  localexp : OperandValue.t;
  flags : Int32.t;
  hand : Int32.t;
  reloffset : Int32.t;
  offsetbase : Int32.t;
  minimumlength : Int32.t;
  mapped : 'oper_artifact;
}

type operand_ptr_t = (TuplePtr.t, SubtablePtr.t, Unit.t) operand_poly_t

type epsilon_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  const_space : AddrSpace.t;
}

type varnode_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  space : AddrSpace.t;
  offset : Int32.t;
  size : Int32.t;
}

type patternless_t = Epsilon of epsilon_t | VarNode of varnode_t

type start_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  const_space : AddrSpace.t;
  patexp : PatternExpression.t;
}

type next2_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  const_space : AddrSpace.t;
  patexp : PatternExpression.t;
}

type ('tuple_t, 'mapped_t, 'oper_artifact) specific_poly_t =
  | End of end_t
  | Operand of ('tuple_t, 'mapped_t, 'oper_artifact) operand_poly_t
  | Patternless of patternless_t
  | Start of start_t
  | Next2 of next2_t

type specific_ptr_t = (TuplePtr.t, SubtablePtr.t, Unit.t) specific_poly_t

type 'operand_t constructor_map_poly_t = {
  id : Int32.t;
  map : 'operand_t constructor_poly_t Int32Map.t;
}

type constructor_map_ptr_t = OperandPtr.t constructor_map_poly_t

type decision_node_t = {
  num : Int32.t;
  contextdecision : Bool.t;
  startbit : Int32.t;
  bitsize : Int32.t;
}

type 'a decision_poly_t =
  | Leaf of decision_node_t * (DisjointPattern.t * 'a) List.t
  | Node of decision_node_t * 'a decision_poly_t List.t

type decision_ptr_t = ConstructorPtr.t decision_poly_t

type 'operand_t decision_middle_t =
  'operand_t constructor_poly_t decision_poly_t

type ('operand_t, 'constructor_t) subtable_poly_t = {
  name : String.t;
  id : Int32.t;
  scopeid : Int32.t;
  construct : 'operand_t constructor_map_poly_t;
  decisiontree : 'constructor_t decision_poly_t;
}

type 'operand_t subtable_middle_t =
  ('operand_t, 'operand_t constructor_poly_t) subtable_poly_t

type subtable_ptr_t = (OperandPtr.t, ConstructorPtr.t) subtable_poly_t

type ('varnode_t, 'tuple_t, 'mapped_t, 'oper_artifact) tuple_poly_t =
  | Family of 'varnode_t family_poly_t
  | Specific of ('tuple_t, 'mapped_t, 'oper_artifact) specific_poly_t

type tuple_ptr_t =
  (VarNodePtr.t, TuplePtr.t, SubtablePtr.t, Unit.t) tuple_poly_t

type ('varnode_t,
       'tuple_t,
       'mapped_t,
       'operand_t,
       'oper_artifact,
       'constructor_t)
     triple_poly_t =
  | Tuple of ('varnode_t, 'tuple_t, 'mapped_t, 'oper_artifact) tuple_poly_t
  | Subtable of ('operand_t, 'constructor_t) subtable_poly_t

type triple_ptr_t =
  ( VarNodePtr.t,
    TuplePtr.t,
    SubtablePtr.t,
    OperandPtr.t,
    Unit.t,
    ConstructorPtr.t )
  triple_poly_t

type ('varnode_t,
       'tuple_t,
       'mapped_t,
       'oper_artifact,
       'operand_t,
       'constructor_t)
     sym_poly_t =
  | Triple of
      ( 'varnode_t,
        'tuple_t,
        'mapped_t,
        'oper_artifact,
        'operand_t,
        'constructor_t )
      triple_poly_t
  | UserOp of user_t

type sym_ptr_t =
  ( VarNodePtr.t,
    TuplePtr.t,
    SubtablePtr.t,
    OperandPtr.t,
    Unit.t,
    ConstructorPtr.t )
  sym_poly_t

(* resolve recursion *)
type ('mapped_t, 'oper_artifact) operand_t =
  ( ('mapped_t, 'oper_artifact) tuple_t,
    'mapped_t,
    'oper_artifact )
  operand_poly_t

and ('mapped_t, 'oper_artifact) tuple_t =
  | Family of varnode_t family_poly_t
  | Specific of
      ( ('mapped_t, 'oper_artifact) tuple_t,
        'mapped_t,
        'oper_artifact )
      specific_poly_t

type ('mapped_t, 'oper_artifact) constructor_t =
  ('mapped_t, 'oper_artifact) operand_t constructor_poly_t

type operand_unmapped = (SubtablePtr.t, Unit.t) operand_t
type constructor_unmapped = (SubtablePtr.t, Unit.t) operand_t constructor_poly_t

type 'mapped_t operand_mapped =
  ('mapped_t constructor_mapped, 'mapped_t) operand_t

and 'mapped_t constructor_mapped =
  | C of 'mapped_t operand_mapped constructor_poly_t

(* also recursion for matching *)
type disas_artifact = { offset : Int32.t; length : Int32.t }
type operand_disas = disas_artifact operand_mapped
type constructor_disas = disas_artifact constructor_mapped

type handle_artifact = {
  offset : Int32.t;
  length : Int32.t;
  handle : FixedHandle.t;
}

type operand_handle = handle_artifact operand_mapped
type constructor_handle = handle_artifact constructor_mapped
type tuple_unmapped = (SubtablePtr.t, Unit.t) tuple_t
type tuple_disas = (constructor_disas, disas_artifact) tuple_t

type 'mapped_t constructor_map_t =
  ('mapped_t, Unit.t) operand_t constructor_map_poly_t

type constructor_map_unmapped = SubtablePtr.t constructor_map_t
type constructor_map_disas = constructor_disas constructor_map_t
type varnodelist_t = varnode_t varnodelist_poly_t
type value_t = varnode_t value_poly_t
type family_t = varnode_t family_poly_t
type 'mapped_t decision_t = ('mapped_t, Unit.t) constructor_t decision_poly_t
type decision_unmapped = SubtablePtr.t decision_t
type decision_disas = constructor_disas decision_t

type 'mapped_t subtable_t =
  ( ('mapped_t, Unit.t) operand_t,
    ('mapped_t, Unit.t) constructor_t )
  subtable_poly_t

type subtable_unmapped = SubtablePtr.t subtable_t
type subtable_disas = constructor_disas subtable_t

type 'mapped_t specific_t =
  (('mapped_t, Unit.t) tuple_t, 'mapped_t, Unit.t) specific_poly_t

type specific_unmapped = SubtablePtr.t specific_t
type specific_disas = constructor_disas specific_t

type 'mapped_t triple_t =
  | Tuple of ('mapped_t, Unit.t) tuple_t
  | Subtable of
      ( ('mapped_t, Unit.t) operand_t,
        ('mapped_t, Unit.t) constructor_t )
      subtable_poly_t

type triple_unmapped = SubtablePtr.t triple_t
type triple_disas = constructor_disas triple_t

type 'mapped_t sym_t =
  ( varnode_t,
    ('mapped_t, Unit.t) tuple_t,
    'mapped_t,
    ('mapped_t, Unit.t) operand_t,
    Unit.t,
    ('mapped_t, Unit.t) constructor_t )
  sym_poly_t

type sym_unmapped = SubtablePtr.t sym_t
type sym_disas = constructor_disas sym_t
