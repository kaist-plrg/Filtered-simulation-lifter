type 'const_t poly_t =
  | Register of RegId.t_full
  | Const of 'const_t
  | Ram of 'const_t

module type S = sig
  type const_t
  type t = const_t poly_t

  val pp : Format.formatter -> t -> unit
  val compare : t -> t -> int
  val get_width : t -> Int32.t
end

module Make (Const : sig
  type t

  val pp : Format.formatter -> t -> unit
  val get_width : t -> Int32.t
end) =
struct
  type const_t = Const.t
  type t = const_t poly_t

  let pp (fmt : Format.formatter) (v : t) =
    match v with
    | Register n -> Format.fprintf fmt "%a" RegId.pp_full n
    | Ram n -> Format.fprintf fmt "*[ram]%a" Const.pp n
    | Const n -> Format.fprintf fmt "%a" Const.pp n

  let compare = compare

  let get_width = function
    | Register n -> n.width
    | Const n -> Const.get_width n
    | Ram n -> Const.get_width n
end
