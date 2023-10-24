open StdlibExt
open Basic
open Basic_domain
open Value_domain
open Ghidra_server

let usage_msg = "interpreter -i <ifile>"
let ghidra_path = ref ""
let ifile = ref ""
let func_name = ref ""
let cwd = ref ""
let repl = ref false

let speclist =
  [
    ("-i", Arg.Set_string ifile, ": input file");
    ("-project-cwd", Arg.Set_string cwd, ": set cwd");
    ("-func", Arg.Set_string func_name, ": target func name");
    ("-debug", Arg.Unit (fun _ -> Logger.set_level Logger.Debug), ": debug mode");
    ("-repl", Arg.Set repl, ": repl mode");
  ]

let () =
  match Sys.getenv_opt "GHIDRA_PATH" with
  | None ->
      raise
        (Arg.Bad "No ghidra path, please set GHIDRA_PATH environment variable")
  | Some x ->
      ghidra_path := x;
      Arg.parse speclist
        (fun x -> raise (Arg.Bad ("Bad argument : " ^ x)))
        usage_msg;
      if !ifile = "" then raise (Arg.Bad "No input file")
      else if !ghidra_path = "" then raise (Arg.Bad "No ghidra path")
      else
        let target_func = if !func_name = "" then "main" else !func_name in
        let cwd = if String.equal !cwd "" then Sys.getcwd () else !cwd in
        let tmp_path = Filename.concat cwd "tmp" in
        Logger.debug "Input file is %s\n" !ifile;
        let server = Server.make_server !ifile !ghidra_path tmp_path cwd in
        Logger.debug "func %s\n" target_func;
        let addr = Server.get_func_addr server target_func in

        let l0 : L0.Prog.t =
          { ins_mem = server.instfunc; rom = server.initstate }
        in
        (if !repl then L0.CFA_repl.repl_analysis l0 addr
         else
           let _ = L0.CFA.Immutable.follow_flow l0 addr in
           ());
        Unix.kill server.pid Sys.sigterm