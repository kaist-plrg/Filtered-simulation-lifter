let rec take (n : int) (l : 'a list) : 'a list =
  if n <= 0 then [] else match l with [] -> [] | h :: t -> h :: take (n - 1) t

let rec drop (n : int) (l : 'a list) : 'a list =
  if n <= 0 then l else match l with [] -> [] | _ :: t -> drop (n - 1) t

let rec print_oper (o : OperandSymbol.disas_t) (sla : Sla.t)
    (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (String.t, String.t) Result.t =
  let nwalker = ParserWalker.replace_offset walker o.mapped.offset in
  match o.operand_value with
  | OTriple (Left a) -> (
      match a with
      | Specific (Operand a) -> print_oper o sla nwalker pinfo
      | Specific (End v) -> EndSymbol.print v nwalker pinfo
      | Specific (Start v) -> StartSymbol.print v nwalker pinfo
      | Specific (Next2 v) -> Next2Symbol.print v nwalker pinfo
      | Specific (Patternless v) -> PatternlessSymbol.print v nwalker
      | Family a -> FamilySymbol.print a nwalker pinfo)
  | OTriple (Right i) -> print_constructor i sla nwalker pinfo
  | ODefExp p ->
      let* pexp = Sla.translate_oe sla p in
      PatternExpression.get_value_string pexp nwalker pinfo

and print_constructor (C c : Constructor.disas_t) (sla : Sla.t)
    (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (String.t, String.t) Result.t =
  let* op_list =
    List.map
      (fun (p : TypeDef.printpiece) ->
        match p with
        | Str s -> s |> Result.ok
        | OperInd op ->
            let* op =
              List.nth_opt c.operandIds (Int32.to_int op)
              |> Option.to_result ~none:"OperInd out of bounds"
            in
            print_oper op sla walker pinfo)
      c.printpieces
    |> Result.join_list
  in
  Ok (String.concat "" op_list)

let rec print_mnem (C s : Constructor.disas_t) (sla : Sla.t)
    (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (String.t, String.t) Result.t =
  match s.flowthruIndex with
  | Some i ->
      let* op =
        List.nth_opt s.operandIds (Int32.to_int i)
        |> Option.to_result ~none:"OperInd out of bounds"
      in
      let* s =
        match op.operand_value with
        | OTriple (Right c) -> c |> Result.ok
        | _ -> "OperInd not a constructor" |> Result.error
      in
      print_mnem s sla walker pinfo
  | None ->
      let endind =
        match s.firstWhitespace with
        | -1l -> List.length s.printpieces
        | i -> Int32.to_int i
      in
      let d = take endind s.printpieces in
      let* op_list =
        List.map
          (fun (p : TypeDef.printpiece) ->
            match p with
            | Str s -> s |> Result.ok
            | OperInd op ->
                let* op =
                  List.nth_opt s.operandIds (Int32.to_int op)
                  |> Option.to_result ~none:"OperInd out of bounds"
                in
                print_oper op sla walker pinfo)
          d
        |> Result.join_list
      in
      Ok (String.concat "" op_list)

let rec print_body (C s : Constructor.disas_t) (sla : Sla.t)
    (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (String.t, String.t) Result.t =
  match s.flowthruIndex with
  | Some i ->
      let* op =
        List.nth_opt s.operandIds (Int32.to_int i)
        |> Option.to_result ~none:"OperInd out of bounds"
      in
      let* s =
        match op.operand_value with
        | OTriple (Right c) -> c |> Result.ok
        | _ -> "OperInd not a constructor" |> Result.error
      in
      print_body s sla walker pinfo
  | None -> (
      match s.firstWhitespace with
      | -1l -> "" |> Result.ok
      | i ->
          let i = Int32.to_int i in
          let d = drop i s.printpieces in
          let* op_list =
            List.map
              (fun (p : TypeDef.printpiece) ->
                match p with
                | Str s -> s |> Result.ok
                | OperInd op ->
                    let* op =
                      List.nth_opt s.operandIds (Int32.to_int op)
                      |> Option.to_result ~none:"OperInd out of bounds"
                    in
                    print_oper op sla walker pinfo)
              d
            |> Result.join_list
          in
          Ok (String.concat "" op_list))
