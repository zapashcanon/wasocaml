open Wstate
module Type = Wtype
open Wident
module Local = Wident.Local

type nn =
  | S32
  | S64

type sx =
  | U
  | S

type irelop =
  | Eq
  | Ne
  | Lt of sx
  | Gt of sx
  | Le of sx
  | Ge of sx

type binop =
  | I32_add
  | I32_sub
  | I32_mul
  | I32_and
  | I32_or
  | I32_xor
  | I32_shl
  | I32_shr of sx
  | F64_add
  | F64_sub
  | F64_mul
  | F64_div
  | Ref_eq
  | Array_get of Type.Var.t

type nv_binop =
  | Struct_set of
      { typ : Type.Var.t
      ; field : int
      }

type unop =
  | I31_get_s
  | I31_new
  | Struct_get of
      { typ : Type.Var.t
      ; field : int
      }
  | Struct_get_packed of
      { typ : Type.Var.t
      ; field : int
      ; extend : sx
      }
  | Ref_cast_i31
  | Is_i31
  | Array_len of Type.Var.t

(* Every expression returns exactly one value *)
type t =
  | Var of Local.t
  | I32 of int32
  | I64 of int64
  | F64 of float
  | Ref_func of Func_id.t
  | Let of
      { var : Local.var
      ; typ : Type.atom
      ; defining_expr : t
      ; body : t
      }
  | If_then_else of
      { cond : t
      ; if_expr : t
      ; else_expr : t
      }
  | I_relop of nn * irelop * (t * t)
  | Binop of binop * (t * t)
  | Unop of unop * t
  | Struct_new of Type.Var.t * t list
  | Array_new_fixed of
      { typ : Type.Var.t
      ; fields : t list
      }
  | Call_ref of
      { typ : Type.Var.t
      ; args : t list
      ; func : t
      }
  | Call of
      { args : t list
      ; func : Func_id.t
      }
  | Ref_cast of
      { typ : Type.Var.t
      ; r : t
      }
  | Global_get of Global.t
  | Seq of no_value_expression list * t
  | Let_cont of
      { cont : Block_id.t
      ; params : (Local.var option * Type.atom) list
      ; handler : t
      ; body : t
      }
  | Apply_cont of
      { cont : Block_id.t
      ; args : t list
      }
  | Br_on_cast of
      { value : t
      ; typ : Type.Var.t
      ; if_cast : Block_id.t
      ; if_else : t
      }
  | Br_if of
      { cond : t
      ; if_true : Block_id.t
      ; if_else : t
      }
  | Br_table of
      { cond : t
      ; cases : Block_id.t list
      ; default : Block_id.t
      }
  | Try of
      { body : t
      ; param : Local.var * Type.atom
      ; handler : t
      }
  | Throw of t
  | NR of no_return
  | Unit of no_value_expression

and no_value_expression =
  | NV_seq of no_value_expression list
  | NV_drop of t
  | NV_binop of nv_binop * (t * t)
  | Assign of
      { being_assigned : Local.var
      ; new_value : t
      }
  | Loop of
      { cont : Block_id.t
      ; body : no_value_expression
      }
  | NV_br_if of
      { cond : t
      ; if_true : Block_id.t
      }
  | NV_if_then_else of
      { cond : t
      ; if_expr : no_value_expression
      ; else_expr : no_value_expression
      }
  | NV

and no_return =
  | NR_let_cont of
      { cont : Block_id.t
      ; params : (Local.var option * Type.atom) list
      ; handler : no_return
      ; body : no_return
      }
  | NR_if_then_else of
      { cond : t
      ; if_expr : no_return
      ; else_expr : no_return
      }
  | NR_br_table of
      { cond : t
      ; cases : Block_id.t list
      ; default : Block_id.t
      }
  | NR_br of
      { cont : Block_id.t
      ; arg : t
      }
  | Unreachable

let print_list f sep ppf l =
  Format.pp_print_list
    ~pp_sep:(fun ppf () -> Format.fprintf ppf "%s@ " sep)
    f ppf l

let sx fmt = function
  | U -> Format.fprintf fmt "u"
  | S -> Format.fprintf fmt "s"

let print_irelop fmt : irelop -> Unit.t = function
  | Eq -> Format.fprintf fmt "eq"
  | Ne -> Format.fprintf fmt "ne"
  | Lt s -> Format.fprintf fmt "lt_%a" sx s
  | Gt s -> Format.fprintf fmt "gt_%a" sx s
  | Le s -> Format.fprintf fmt "le_%a" sx s
  | Ge s -> Format.fprintf fmt "ge_%a" sx s

let print_nn fmt = function
  | S32 -> Format.fprintf fmt "32"
  | S64 -> Format.fprintf fmt "64"

let print_binop ppf = function
  | I32_add -> Format.fprintf ppf "I32_add"
  | I32_sub -> Format.fprintf ppf "I32_sub"
  | I32_mul -> Format.fprintf ppf "I32_mul"
  | I32_and -> Format.fprintf ppf "I32_and"
  | I32_or -> Format.fprintf ppf "I32_or"
  | I32_xor -> Format.fprintf ppf "I32_xor"
  | I32_shl -> Format.fprintf ppf "I32_shl"
  | I32_shr s -> Format.fprintf ppf "I32_shr_%a" sx s
  | F64_add -> Format.fprintf ppf "F64_add"
  | F64_sub -> Format.fprintf ppf "F64_sub"
  | F64_mul -> Format.fprintf ppf "F64_mul"
  | F64_div -> Format.fprintf ppf "F64_div"
  | Ref_eq -> Format.fprintf ppf "Ref_eq"
  | Array_get typ ->
    Format.fprintf ppf "@[<hov 2>Array_get(%a)@]" Type.Var.print typ

let print_nv_binop ppf = function
  | Struct_set { typ; field } ->
    Format.fprintf ppf "@[<hov 2>Struct_set(%a).(%i)@]" Type.Var.print typ field

let print_unop ppf = function
  | I31_get_s -> Format.fprintf ppf "I31_get_s"
  | I31_new -> Format.fprintf ppf "I31_new"
  | Struct_get { typ; field } ->
    Format.fprintf ppf "@[<hov 2>Struct_get(%a).(%i)@]" Type.Var.print typ field
  | Struct_get_packed { typ; field; extend } ->
    let str = match extend with S -> "_s" | U -> "_u" in
    Format.fprintf ppf "@[<hov 2>Struct_get%s(%a).(%i)@]" str Type.Var.print typ
      field
  | Ref_cast_i31 -> Format.fprintf ppf "Ref_cast_i31"
  | Is_i31 -> Format.fprintf ppf "Is_i31"
  | Array_len typ ->
    Format.fprintf ppf "@[<hov 2>Array_len(%a)@]" Type.Var.print typ

let rec print ppf = function
  | Var l -> Local.print ppf l
  | I32 i -> Format.fprintf ppf "%li" i
  | I64 i -> Format.fprintf ppf "%Li" i
  | F64 f -> Format.fprintf ppf "%g" f
  | Ref_func f -> Format.fprintf ppf "Ref_func %a" Func_id.print f
  | Let { var; defining_expr; body } ->
    Format.fprintf ppf "@[<hov 2>Let %a =@ %a@]@ in@ %a" Local.print_var var
      print defining_expr print body
  | I_relop (nn, op, (arg1, arg2)) ->
    Format.fprintf ppf "@[<hov 2>I_relop(%a_%a:@ %a,@ %a)@]" print_irelop op
      print_nn nn print arg1 print arg2
  | Binop (binop, (arg1, arg2)) ->
    Format.fprintf ppf "@[<hov 2>Binop(%a:@ %a,@ %a)@]" print_binop binop print
      arg1 print arg2
  | Unop (unop, arg) ->
    Format.fprintf ppf "@[<hov 2>Unop(%a:@ %a)@]" print_unop unop print arg
  | Struct_new (typ, args) ->
    Format.fprintf ppf "@[<hov 2>Struct_new(%a:@ %a)@]" Type.Var.print typ
      (print_list print ",") args
  | Array_new_fixed { typ; fields } ->
    Format.fprintf ppf "@[<hov 2>Array_new_fixed(%a:@ %a)@]" Type.Var.print typ
      (print_list print ",") fields
  | Call_ref { typ; args; func } ->
    Format.fprintf ppf "@[<hov 2>Call_ref(%a:@ %a(%a))@]" Type.Var.print typ
      print func (print_list print ",") args
  | Call { args; func } ->
    Format.fprintf ppf "@[<hov 2>Call(%a(%a))@]" Func_id.print func
      (print_list print ",") args
  | Ref_cast { typ; r } ->
    Format.fprintf ppf "@[<hov 2>Ref_cast(%a:@ %a)@]" Type.Var.print typ print r
  | Global_get g ->
    Format.fprintf ppf "@[<hov 2>Global_get(%a)@]" Global.print g
  | Seq (effects, last) ->
    Format.fprintf ppf "@[<v 2>Seq(%a;%a)@]"
      (print_list print_no_value ";")
      effects print last
  | If_then_else { cond; if_expr; else_expr } ->
    Format.fprintf ppf "@[<hov 2>If(%a)Then(%a)Else(%a)@]" print cond print
      if_expr print else_expr
  | Let_cont { cont; params; handler; body } ->
    Format.fprintf ppf "@[<hov 2>Let_cont %a(%a) =@ %a@]@ in@ %a" Block_id.print
      cont
      (print_list
         (fun ppf (local, typ) ->
           Format.fprintf ppf "%a : %a"
             (Format.pp_print_option Local.print_var)
             local Type.print_atom typ )
         ", " )
      params print handler print body
  | Apply_cont { cont; args } ->
    Format.fprintf ppf "@[<hov 2>Apply_cont(%a(%a))@]" Block_id.print cont
      (print_list print ",") args
  | Br_on_cast { value; typ; if_cast; if_else } ->
    Format.fprintf ppf "@[<hov 2>Br_on_cast(%a %a -> (%a) else %a)@]" print
      value Type.Var.print typ Block_id.print if_cast print if_else
  | Br_if { cond; if_true; if_else } ->
    Format.fprintf ppf "@[<hov 2>Br_if(%a -> (%a) else %a)@]" print cond
      Block_id.print if_true print if_else
  | Br_table { cond; cases; default } ->
    Format.fprintf ppf "@[<hov 2>Br_table(%a -> (%a) %a@]" print cond
      (print_list Block_id.print " ")
      cases Block_id.print default
  | Try _ | Throw _ -> failwith "TODO print exn"
  | Unit nv -> Format.fprintf ppf "@[<hov 2>Unit (@ %a@ )@]" print_no_value nv
  | NR nr -> print_no_return ppf nr

and print_no_value ppf no_value =
  match no_value with
  | NV_seq effects ->
    Format.fprintf ppf "@[<v 2>Seq(%a)@]"
      (print_list print_no_value ";")
      effects
  | NV_drop e -> Format.fprintf ppf "@[<hov 2>Drop (@ %a@ )@]" print e
  | NV_binop (binop, (arg1, arg2)) ->
    Format.fprintf ppf "@[<hov 2>Binop(%a:@ %a,@ %a)@]" print_nv_binop binop
      print arg1 print arg2
  | Assign { being_assigned; new_value } ->
    Format.fprintf ppf "@[<v 2>Assign(%a <- %a)@]" Local.print_var
      being_assigned print new_value
  | Loop { cont; body } ->
    Format.fprintf ppf "@[<hov 2>Loop %a@ %a@]" Block_id.print cont
      print_no_value body
  | NV -> Format.fprintf ppf "Nil"
  | NV_if_then_else { cond; if_expr; else_expr } ->
    Format.fprintf ppf "@[<hov 2>If(%a)Then(%a)Else(%a)@]" print cond
      print_no_value if_expr print_no_value else_expr
  | NV_br_if { cond; if_true } ->
    Format.fprintf ppf "@[<hov 2>Br_if(%a -> (%a))@]" print cond Block_id.print
      if_true

and print_no_return ppf no_return =
  match no_return with
  | NR_if_then_else { cond; if_expr; else_expr } ->
    Format.fprintf ppf "@[<hov 2>If(%a)Then(%a)Else(%a)@]" print cond
      print_no_return if_expr print_no_return else_expr
  | NR_br_table { cond; cases; default } ->
    Format.fprintf ppf "@[<hov 2>Br_table(%a -> (%a) %a@]" print cond
      (print_list Block_id.print " ")
      cases Block_id.print default
  | NR_let_cont { cont; params; handler; body } ->
    Format.fprintf ppf "@[<hov 2>Let_cont %a(%a) =@ %a@]@ in@ %a" Block_id.print
      cont
      (print_list
         (fun ppf (local, typ) ->
           Format.fprintf ppf "%a : %a"
             (Format.pp_print_option Local.print_var)
             local Type.print_atom typ )
         ", " )
      params print_no_return handler print_no_return body
  | NR_br { cont; arg } ->
    Format.fprintf ppf "@[<hov 2>Br(%a, %a)@]" Block_id.print cont print arg
  | Unreachable -> Format.fprintf ppf "Unreachable"

let let_ var typ defining_expr body = Let { var; typ; defining_expr; body }

type function_body =
  | Value of t * Type.atom
  | No_value of no_value_expression

let required_locals body =
  let add var typ acc =
    match Local.Map.find var acc with
    | prev_typ ->
      assert (typ = prev_typ);
      acc
    | exception Not_found -> Local.Map.add var typ acc
  in
  let let_cont_reqs acc ~cont ~params =
    let acc =
      List.fold_left
        (fun acc (var, typ) ->
          match var with None -> acc | Some var -> add var typ acc )
        acc params
    in
    let acc =
      match (mode, params) with
      | Binarien, _ :: _ :: _ ->
        let var = Local.Block_result cont in
        add var (Type.Tuple (List.map snd params)) acc
      | _ -> acc
    in
    acc
  in
  let rec loop acc = function
    | Var _ | I32 _ | I64 _ | F64 _ | Ref_func _ -> acc
    | Let { var; typ; defining_expr; body } ->
      let acc = add var typ acc in
      let acc = loop acc defining_expr in
      loop acc body
    | I_relop (_, _, (arg1, arg2)) | Binop (_, (arg1, arg2)) ->
      let acc = loop acc arg1 in
      loop acc arg2
    | If_then_else { cond; if_expr; else_expr } ->
      let acc = loop acc cond in
      let acc = loop acc if_expr in
      loop acc else_expr
    | Unop (_op, arg) -> loop acc arg
    | Struct_new (_typ, args) ->
      List.fold_left (fun acc arg -> loop acc arg) acc args
    | Array_new_fixed { typ = _; fields } ->
      List.fold_left (fun acc arg -> loop acc arg) acc fields
    | Call_ref { typ = _; args; func } ->
      List.fold_left (fun acc arg -> loop acc arg) (loop acc func) args
    | Call { args; func = _ } ->
      List.fold_left (fun acc arg -> loop acc arg) acc args
    | Ref_cast { typ = _; r } -> loop acc r
    | Global_get _ -> acc
    | Seq (effects, last) ->
      let acc =
        List.fold_left (fun acc arg -> loop_no_value acc arg) acc effects
      in
      loop acc last
    | Let_cont { cont; params; handler; body } ->
      let acc = let_cont_reqs acc ~cont ~params in
      let acc = loop acc handler in
      loop acc body
    | Apply_cont { cont = _; args } ->
      List.fold_left (fun acc arg -> loop acc arg) acc args
    | Br_on_cast { value; if_cast = _; if_else } ->
      let acc = loop acc value in
      loop acc if_else
    | Br_if { cond; if_true = _; if_else } ->
      let acc = loop acc cond in
      loop acc if_else
    | Br_table { cond; cases = _; default = _ } -> loop acc cond
    | Try { body; handler; param = local, typ } ->
      let acc = add local typ acc in
      let acc = loop acc body in
      loop acc handler
    | Throw e -> loop acc e
    | Unit nv -> loop_no_value acc nv
    | NR nr -> loop_no_return acc nr
  and loop_no_value acc nv =
    match nv with
    | NV -> acc
    | NV_seq effects ->
      List.fold_left (fun acc arg -> loop_no_value acc arg) acc effects
    | NV_drop e -> loop acc e
    | NV_binop (_op, (arg1, arg2)) ->
      let acc = loop acc arg1 in
      loop acc arg2
    | Assign { being_assigned = _; new_value } -> loop acc new_value
    | Loop { cont = _; body } -> loop_no_value acc body
    | NV_br_if { cond; if_true = _ } -> loop acc cond
    | NV_if_then_else { cond; if_expr; else_expr } ->
      let acc = loop acc cond in
      let acc = loop_no_value acc if_expr in
      loop_no_value acc else_expr
  and loop_no_return acc nr =
    match nr with
    | NR_if_then_else { cond; if_expr; else_expr } ->
      let acc = loop acc cond in
      let acc = loop_no_return acc if_expr in
      loop_no_return acc else_expr
    | NR_br_table { cond; cases = _; default = _ } -> loop acc cond
    | NR_let_cont { cont; params; handler; body } ->
      let acc = let_cont_reqs acc ~cont ~params in
      let acc = loop_no_return acc handler in
      loop_no_return acc body
    | NR_br { cont = _; arg } -> loop acc arg
    | Unreachable -> acc
  in
  match body with
  | Value (expr, _typ) -> loop Local.Map.empty expr
  | No_value expr -> loop_no_value Local.Map.empty expr
