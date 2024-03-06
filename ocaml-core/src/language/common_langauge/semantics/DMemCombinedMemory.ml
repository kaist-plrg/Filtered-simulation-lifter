open Basic
open Basic_collection
include AddrMap

type t = { ram : Char.t AddrMap.t; rom : DMem.t }

let from_rom (rom : DMem.t) : t = { ram = AddrMap.empty; rom }

let find (s : t) (addr : Addr.t) : Char.t =
  AddrMap.find_opt addr s.ram
  |> Option.value ~default:(DMem.get_byte s.rom addr)

let load_mem (s : t) (addr : Addr.t) (width : Int32.t) : NumericValue.t =
  let rec aux (addr : Addr.t) (width : Int32.t) (acc : Char.t list) :
      Char.t list =
    if width = 0l then acc
    else
      let c = find s addr in
      aux (Addr.succ addr) (Int32.pred width) (c :: acc)
  in
  let chars = aux addr width [] |> List.rev in
  NumericValue.of_chars chars

let load_string (s : t) (addr : Addr.t) : string =
  let rec aux (addr : Addr.t) (acc : string) : string =
    let c = find s addr in
    if c = Char.chr 0 then acc else aux (Addr.succ addr) (acc ^ String.make 1 c)
  in
  aux addr ""

let store_mem (s : t) (addr : Addr.t) (v : NumericValue.t) : t =
  let chars = NumericValue.to_chars v in
  let rec aux (addr : Addr.t) (chars : Char.t list) (acc : Char.t AddrMap.t) :
      Char.t AddrMap.t =
    match chars with
    | [] -> acc
    | c :: chars ->
        let acc = AddrMap.add addr c acc in
        aux (Addr.succ addr) chars acc
  in
  { s with ram = aux addr chars s.ram }