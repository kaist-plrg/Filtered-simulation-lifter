include Hashtbl.Make (struct
  type t = Loc.t

  let equal = ( = )
  let hash = Hashtbl.hash
end)
