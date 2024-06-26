let eval (b : Bop.t) (lv : NumericValue.t) (rv : NumericValue.t)
    (outwidth : Int32.t) : (NumericValue.t, String.t) Result.t =
  let* ln = NumericValue.value_64 lv in
  let* rn = NumericValue.value_64 rv in
  match b with
  | Bpiece -> List.append rv lv |> Result.ok
  | Bsubpiece ->
      NumericValue.sublist lv (Int64.to_int rn) (Int32.to_int outwidth)
      |> Result.ok
  | Bint_equal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_equal: different bitwidth"
      else NumericValue.of_int64_safe (if lv = rv then 1L else 0L) outwidth
  | Bint_notequal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_notequal: different bitwidth"
      else NumericValue.of_int64_safe (if lv <> rv then 1L else 0L) outwidth
  | Bint_less ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_less: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if Int64.unsigned_compare ln rn < 0 then 1L else 0L)
          outwidth
  | Bint_sless ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_sless: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if
             Int64.compare
               (Int64.sext ln (NumericValue.width lv) 8l)
               (Int64.sext rn (NumericValue.width rv) 8l)
             < 0
           then 1L
           else 0L)
          outwidth
  | Bint_lessequal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_lessequal: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if Int64.unsigned_compare ln rn <= 0 then 1L else 0L)
          outwidth
  | Bint_slessequal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_slessequal: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if
             Int64.compare
               (Int64.sext ln (NumericValue.width lv) 8l)
               (Int64.sext rn (NumericValue.width rv) 8l)
             <= 0
           then 1L
           else 0L)
          outwidth
  | Bint_add ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_add: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.add ln rn) outwidth)
          outwidth
  | Bint_sub ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_sub: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.sub ln rn) outwidth)
          outwidth
  | Bint_carry ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_carry: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if Int64.carry ln rn (NumericValue.width lv) then 1L else 0L)
          outwidth
  | Bint_scarry ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_scarry: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if Int64.scarry ln rn (NumericValue.width lv) then 1L else 0L)
          outwidth
  | Bint_sborrow ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_sborrow: different bitwidth"
      else
        NumericValue.of_int64_safe
          (if Int64.sborrow ln rn (NumericValue.width lv) then 1L else 0L)
          outwidth
  | Bint_xor ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_add: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.logxor ln rn) outwidth)
          outwidth
  | Bint_and ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_add: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.logand ln rn) outwidth)
          outwidth
  | Bint_or ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_add: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.logor ln rn) outwidth)
          outwidth
  | Bint_left ->
      NumericValue.of_int64_safe
        (Int64.cut_width (Int64.shift_left ln (Int64.to_int rn)) outwidth)
        outwidth
  | Bint_right ->
      NumericValue.of_int64_safe
        (Int64.cut_width
           (Int64.shift_right_logical ln (Int64.to_int rn))
           outwidth)
        outwidth
  | Bint_sright ->
      NumericValue.of_int64_safe
        (Int64.cut_width
           (Int64.shift_right
              (Int64.sext ln (NumericValue.width lv) 8l)
              (Int64.to_int rn))
           outwidth)
        outwidth
  | Bint_mult ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_mul: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.mul ln rn) outwidth)
          outwidth
  | Bint_div ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_div: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.unsigned_div ln rn) outwidth)
          outwidth
  | Bint_rem ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_rem: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.unsigned_rem ln rn) outwidth)
          outwidth
  | Bint_sdiv ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_sdiv: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.div ln rn) outwidth)
          outwidth
  | Bint_srem ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "int_srem: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width (Int64.rem ln rn) outwidth)
          outwidth
  | Bbool_xor ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "bool_xor: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width
             (Int64.logxor (Int64.logand ln 1L) (Int64.logand rn 1L))
             outwidth)
          outwidth
  | Bbool_and ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "bool_xor: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width
             (Int64.logand (Int64.logand ln 1L) (Int64.logand rn 1L))
             outwidth)
          outwidth
  | Bbool_or ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "bool_xor: different bitwidth"
      else
        NumericValue.of_int64_safe
          (Int64.cut_width
             (Int64.logor (Int64.logand ln 1L) (Int64.logand rn 1L))
             outwidth)
          outwidth
  | Bfloat_equal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_equal: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let rv = if Float.compare lf rf = 0 then 1L else 0L in
        [%log finfo "float" "%f = %f = %Lx" lf rf rv];
        NumericValue.of_int64_safe rv outwidth
  | Bfloat_notequal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_notequal: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let rv = if Float.compare lf rf <> 0 then 1L else 0L in
        [%log finfo "float" "%f <> %f = %Lx" lf rf rv];
        NumericValue.of_int64_safe rv outwidth
  | Bfloat_less ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_less: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let rv = if Float.compare lf rf < 0 then 1L else 0L in
        [%log finfo "float" "%f < %f = %Lx" lf rf rv];
        NumericValue.of_int64_safe rv outwidth
  | Bfloat_lessequal ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_lessequal: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let rv = if Float.compare lf rf <= 0 then 1L else 0L in
        [%log finfo "float" "%f <= %f = %Lx" lf rf rv];
        NumericValue.of_int64_safe rv outwidth
  | Bfloat_add ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_add: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let fv = Float.add lf rf in
        [%log finfo "float" "%f + %f = %f" lf rf fv];
        let* fv = Int64.of_float_width fv outwidth in
        NumericValue.of_int64_safe fv outwidth
  | Bfloat_sub ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_sub: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let fv = Float.sub lf rf in
        [%log finfo "float" "%f - %f = %f" lf rf fv];
        let* fv = Int64.of_float_width fv outwidth in
        NumericValue.of_int64_safe fv outwidth
  | Bfloat_mult ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_mult: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let fv = Float.mul lf rf in
        [%log finfo "float" "%f * %f = %f" lf rf fv];
        let* fv = Int64.of_float_width fv outwidth in
        NumericValue.of_int64_safe fv outwidth
  | Bfloat_div ->
      if NumericValue.width lv <> NumericValue.width rv then
        Error "float_div: different bitwidth"
      else
        let* lf = Int64.to_float_width ln (NumericValue.width lv) in
        let* rf = Int64.to_float_width rn (NumericValue.width rv) in
        let fv = Float.div lf rf in
        [%log finfo "float" "%f / %f = %f" lf rf fv];
        let* fv = Int64.of_float_width fv outwidth in
        NumericValue.of_int64_safe fv outwidth
