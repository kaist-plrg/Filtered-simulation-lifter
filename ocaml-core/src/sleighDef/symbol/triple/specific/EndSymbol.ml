type t = TypeDef.end_t

let decode (xml : Xml.xml) (sleighInit : SleighInit.t) (header : SymbolHeader.t)
    : (t, String.t) Result.t =
  let* const_space = SleighInit.get_constant_space sleighInit in
  let patexp = PatternExpression.of_end () in
  ({
     name = header.name;
     id = header.id;
     scopeid = header.scopeid;
     const_space;
     patexp;
   }
    : t)
  |> Result.ok

let get_name (symbol : t) : String.t = symbol.name
let get_id (symbol : t) : Int32.t = symbol.id
let get_scopeid (symbol : t) : Int32.t = symbol.scopeid

let print (v : t) (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (String.t, String.t) Result.t =
  let v = Common.Byte8.get_offset pinfo.naddr in
  Format.sprintf "0x%Lx" v |> Result.ok

let getFixedHandle (v : t) (walker : ParserWalker.t) (pinfo : PatternInfo.t) :
    (FixedHandle.t, String.t) Result.t =
  let v = Common.Byte8.get_offset pinfo.naddr in
  FixedHandle.of_constant v |> Result.ok
